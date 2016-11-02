package CNCTool::Project;

use Moose;
use File::Path qw( make_path );
use CNCTool::Slice;
use CNCTool::Logger;

has project => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has stl => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has project_root => (
    is => 'ro',
    isa => 'Str',
    default => './',
    required => 0,
);

has steps_per_mm => (
    is => 'ro',
    isa => 'Num',
    required => 0,
);

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

has logger => (
    is => 'ro',
    isa => 'Object',
    required => 0,
    builder => '_build_logger',
);

sub _build_logger {
    my ( $self ) = @_;
    return CNCTool::Logger->new;
}

sub BUILD {
    my ( $self ) = @_;
    $self->make_project_dir;
}

sub generate_dir {
    my ( $self, @path ) = @_;

    my $dir = sprintf( '%s/projects/%s', $self->project_root, $self->project );
    if ( @path ) {
        $dir .= '/' . join( '/', @path );
    }

    return $dir;
}

sub make_project_dir {
    my ( $self, @path ) = @_;
    my $dir = $self->generate_dir( @path );
    make_path( $dir );
}

sub slice_model {
    my ( $self ) = @_;

    $self->make_project_dir( 'raw_layer_files' );

    my $slicer = CNCTool::Slice->new( { file => $self->stl } );

    my $min_travel = $self->min_travel;
    my $max_height = $slicer->max_height;
    my $min_height = $slicer->min_height;

    my @z_heights;
    for ( my $z = $max_height; $z > $min_height; $z -= $min_travel ) {
        push @z_heights, sprintf( '%0.4f', $z );
    }

    $self->logger->debug( 'calculated %d layers to slice', scalar( @z_heights ) );

    my $count = 0;
    for my $z ( @z_heights ) {
        $self->logger->debug( 'slicing at %0.4f', $z );
        my $layer = $slicer->layer_at_z( $z );
        $self->save_layer( $count, $layer );
        $count++;
    }
}

sub save_layer {
    my ( $self, $count, $layer ) = @_;

use Data::Dumper;
    my $file_name = sprintf( '%05d.layer', $count );
    my $content = Data::Dumper->new( [ $layer ], [ 'layer' ] )->Indent( 1 )->Dump;

    $self->save_file( 'raw_layer_files', $file_name, $content );
}

sub save_file {
    my ( $self, $subdir, $file_name, $content ) = @_;

    my $dir = $self->generate_dir( $subdir );
    my $name = $dir . '/' . $file_name;

    open( my $fh, '>', $name ) || die "opening: $name: $!";
    print $fh $content;
    close $fh;
}

__PACKAGE__->meta->make_immutable;
