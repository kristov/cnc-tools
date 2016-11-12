package CNCTool::Program::FindUniqLayers;

use Moose;
use File::Path qw( make_path );
use CNCTool::Slice;
use CNCTool::Logger;

sub options {
    return [];
}

has project => (
    is => 'ro',
    isa => 'CNCTool::Project',
    required => 1,
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
        @files = grep { $_ =~ /^[0-9\.]+\.layer/ } @files;
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

sub raw_layer_files_dir {
    my ( $self ) = @_;
    return $self->project->generate_dir( 'raw_layer_files' );
}

sub run {
    my ( $self ) = @_;

    my $files = $self->layer_files;
    my $prev_layer;

    for my $file ( @{ $files } ) {
        my $layer = $self->load_layer_file( $file );
        if ( $prev_layer ) {
            if ( $layer->equal( $prev_layer ) ) {
                $self->project->logger->debug( 'equal!' );
            }
        }
        $prev_layer = $layer;
    }
}

sub save_layer {
    my ( $self, $ident, $layer ) = @_;

    my $file_name = sprintf( '%0.5f.layer', $ident );

    my $content = $self->project->serialise_layer( $layer );
    $self->project->save_file( 'raw_layer_files', $file_name, $content );
}

sub load_layer_file {
    my ( $self, $file_name ) = @_;
    my $content = $self->project->load_file( 'raw_layer_files', $file_name );
    return $self->project->deserialise_layer( $content );
}

__PACKAGE__->meta->make_immutable;
