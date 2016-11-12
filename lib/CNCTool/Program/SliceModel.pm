package CNCTool::Program::SliceModel;

use Moose;
use File::Path qw( make_path );
use CNCTool::Slice;
use CNCTool::Logger;

sub options {
    return [
        {
            name    => 'stl_file',
            type    => 'file',
            req     => 1,
            desc    => 'STL file to slice',
        },
        {
            name    => 'steps_per_mm',
            type    => 'decimal',
            req     => 0,
            desc    => 'Number of steps per mm of machine',
        }
    ];
}

has project => (
    is => 'ro',
    isa => 'CNCTool::Project',
    required => 1,
);

has stl_file => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has steps_per_mm => (
    is => 'ro',
    isa => 'Num',
    required => 0,
);

has layer_files => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    lazy => 1,
    builder => '_build_layer_files',
);

sub _build_layer_files {
    my ( $self ) = @_;

    my $raw_layer_files_dir = $self->raw_layer_files_dir;

    if ( -d $raw_layer_files_dir ) {
        opendir( my $dfh, $raw_layer_files_dir ) || die "reading $raw_layer_files_dir: $!";
        my @files = readdir( $dfh );
        closedir( $dfh );
        @files = grep { $_ =~ /^[0-9]+\.layer/ } @files;
        return \@files;
    }
    return [];
}

has nr_layers => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    builder => '_build_nr_layers',
);

sub _build_nr_layers {
    my ( $self ) = @_;
    my $layer_files = $self->layer_files;
    return scalar( @{ $layer_files } );
}

has min_travel => (
    is => 'ro',
    isa => 'Num',
    required => 0,
    builder => '_build_min_travel',
);

sub _build_min_travel {
    my ( $self ) = @_;
    my $steps_per_mm = $self->steps_per_mm // 314.961;
    return sprintf( '%0.4f', 1 / $steps_per_mm );
}

sub raw_layer_files_dir {
    my ( $self ) = @_;
    return $self->project->generate_dir( 'raw_layer_files' );
}

sub run {
    my ( $self ) = @_;
    $self->project->make_project_dir( 'raw_layer_files' );
    $self->slice_model;
}

sub slice_model {
    my ( $self ) = @_;

    my $slicer = CNCTool::Slice->new( { file => $self->stl_file } );

    my $min_travel = $self->min_travel;
    my $max_height = $slicer->max_height;
    my $min_height = $slicer->min_height;

    my @z_heights;
    for ( my $z = $max_height; $z > $min_height; $z -= $min_travel ) {
        push @z_heights, sprintf( '%0.4f', $z );
    }

    my $nr_layers = scalar( @z_heights );
    $self->nr_layers( $nr_layers );
    $self->project->logger->debug( 'calculated %d layers to slice', $nr_layers );

    $self->_slice_multi_process( $slicer, @z_heights );
}

sub _slice_single_process {
    my ( $self, $slicer, @z_heights ) = @_;

    for my $z ( @z_heights ) {
        $self->project->logger->debug( 'slicing at %0.4f', $z );
        my $layer = $slicer->layer_at_z( $z );
        $self->save_layer( $z, $layer );
    }
}

sub _slice_multi_process {
    my ( $self, $slicer, @z_heights ) = @_;

    my $cpu_count = $self->_cpu_count;
    $self->project->logger->debug( 'detected %d CPUs', $cpu_count );

    require Parallel::ForkManager;
    my $pm = Parallel::ForkManager->new( $cpu_count );

    DATA_LOOP: for my $z ( @z_heights ) {
        my $pid = $pm->start and next DATA_LOOP;

        $self->project->logger->debug( 'PID %d: slicing at %0.4f', $$, $z );
        my $layer = $slicer->layer_at_z( $z );
        $self->save_layer( $z, $layer );

        $pm->finish;
    }
}

sub _cpu_count {
    my ( $self ) = @_;
    my $cpu_count = `grep -c -P '^processor\\s+:' /proc/cpuinfo`;
    chomp $cpu_count;
    return $cpu_count;
}

sub unique_layers {
    my ( $self ) = @_;
    my $layer_files = $self->layer_files;

    for my $file ( @{ $layer_files }[0..5] ) {
        if ( $file =~ /^([0-9]+)\./ ) {
            my $data = $self->load_layer( $1 + 0 );
            print Dumper( $data );
        }
    }
}

sub save_layer {
    my ( $self, $ident, $layer ) = @_;

    my $file_name = sprintf( '%0.5f.layer', $ident );

    my $content = $self->project->serialise_layer( $layer );
    $self->project->save_file( 'raw_layer_files', $file_name, $content );
}

sub load_layer {
    my ( $self, $count ) = @_;

    my $file_name = sprintf( '%05d.layer', $count );

    my $content = $self->project->load_file( 'raw_layer_files', $file_name );
    return $self->project->deserialise_layer( $content );
}

__PACKAGE__->meta->make_immutable;
