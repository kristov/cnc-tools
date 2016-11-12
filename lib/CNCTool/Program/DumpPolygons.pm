package CNCTool::Program::DumpPolygons;

use Moose;

sub options {
    return [
        {
            name    => 'z',
            type    => 'decimal',
            req     => 1,
            desc    => 'The Z axis height to view the slice',
        },
    ];
}

has project => (
    is => 'ro',
    isa => 'CNCTool::Project',
    required => 1,
);

has z => (
    is => 'rw',
    isa => 'Num',
    required => 1,
);

has layer => (
    is => 'rw',
    isa => 'ACME::Geo::Layer',
    lazy => 1,
    builder => '_build_layer',
);

sub _build_layer {
    my ( $self ) = @_;

    my @raw_layer_files = $self->project->files_in_dir( 'raw_layer_files' );
    if ( @raw_layer_files ) {
        my $z = $self->_closest( $self->z, @raw_layer_files );
        $self->z( $z );
        my $file_name = sprintf( '%0.5f.layer', $z );
        $self->project->logger->debug( 'found %s', $file_name );
        my $content = $self->project->load_file( 'raw_layer_files', $file_name );
        return $self->project->deserialise_layer( $content );
    }
}

has layer_files => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    lazy => 1,
    builder => '_build_layer_files',
);

sub _build_layer_files {
    my ( $self ) = @_;
    my @raw_layer_files = $self->project->files_in_dir( 'raw_layer_files' );
    @raw_layer_files = sort { $b cmp $a } @raw_layer_files;
    return \@raw_layer_files;
}

sub _closest {
    my ( $self, $z, @raw_layer_files ) = @_;

    my @numbers;
    for my $file ( @raw_layer_files ) {
        if ( $file =~ /^([0-9\.]+)\.layer$/ ) {
            push @numbers, $1;
        }
    }

    @numbers = sort { $a <=> $b } @numbers;
    my $last_number;
    for my $number ( @numbers ) {
        return $number if $number == $z;
        return $number if $number > $z;
        $last_number = $number;
    }
    return $last_number;
}

sub run {
    my ( $self ) = @_;

    my $layer = $self->layer;

    my $count = 0;
    for my $path ( @{ $layer } ) {
        $self->save_path( $count, $path );
        $count++;
    }
}

sub save_path {
    my ( $self, $ident, $path ) = @_;

    my $zdir_name = sprintf( '%0.5f.layer', $self->z );
    my $file_name = sprintf( '%0.5f.path', $ident );

    $self->project->make_project_dir( "raw_path_files/$zdir_name" );
    my $content = $self->project->serialise_path( $path );
    $self->project->save_file( "raw_path_files/$zdir_name", $file_name, $content );
}

__PACKAGE__->meta->make_immutable;
