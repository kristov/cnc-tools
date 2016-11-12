package CNCTool::Project;

use Moose;
use File::Path qw( make_path );
use CNCTool::Slice;
use CNCTool::Logger;
use Getopt::Long;
use ACME::Geo::Util::Converter;
use CNCTool::Program::SliceView;
use CNCTool::Program::PathView;
use CNCTool::Program::SliceModel;
use CNCTool::Program::FindUniqLayers;
use CNCTool::Program::DumpPolygons;

has project_name => (
    is => 'rw',
    isa => 'Str',
    required => 0,
);

has program_name => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has program_class => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {
        return {
            'slice-model'       => 'CNCTool::Program::SliceModel',
            'slice-view'        => 'CNCTool::Program::SliceView',
            'path-view'         => 'CNCTool::Program::PathView',
            'find-uniq-layers'  => 'CNCTool::Program::FindUniqLayers',
            'dump-polygons'     => 'CNCTool::Program::DumpPolygons',
        };
    },
);

has program => (
    is => 'rw',
    isa => 'Object',
);

sub get_options {
    my ( $self, $options ) = @_;

    my @def = @{ $options || [] };

    my @opts = (
        'project=s',
        'help',
    );

    for my $def ( @def ) {
        if ( $def->{type} eq 'bool' ) {
            push @opts, $def->{name};
        }
        else {
            push @opts, $def->{name} . '=s';
        }
    }

    my $args = {};
    GetOptions(
        $args,
        @opts,
    );

    if ( $args->{help} ) {
        $self->print_help;
    }

    return $args;
}

has project_root => (
    is => 'ro',
    isa => 'Str',
    default => '.',
    required => 0,
);

has logger => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    builder => '_build_logger',
);

sub _build_logger {
    my ( $self ) = @_;
    return CNCTool::Logger->new;
}

has converter => (
    is => 'ro',
    isa => 'ACME::Geo::Util::Converter',
    lazy => 1,
    builder => '_build_converter',
);

sub _build_converter {
    my ( $self ) = @_;
    return ACME::Geo::Util::Converter->new;
}

sub BUILD {
    my ( $self ) = @_;

    my $program_name = $self->program_name;

    my $program_class = $self->program_class->{$program_name}
        || die "unknown program_name: $program_name";

    my $options = $program_class->options;
    my $args = $self->get_options( $options );

    $self->project_name( delete $args->{project} );

    my $program_object = $program_class->new( { project => $self, %{ $args } } );

    $self->program( $program_object );

    $self->make_project_dir;
}

sub generate_dir {
    my ( $self, @path ) = @_;

    my $dir = sprintf( '%s/projects/%s', $self->project_root, $self->project_name );
    if ( @path ) {
        $dir .= '/' . join( '/', @path );
    }

    return $dir;
}

sub files_in_dir {
    my ( $self, @path ) = @_;

    my $dir = $self->generate_dir( @path );

    if ( -d $dir ) {
        opendir( my $dfh, $dir ) || die "error reading $dir: $!";
        my @files = readdir( $dfh );
        closedir( $dfh );
        @files = grep { $_ !~ /^\.{1,2}$/ } @files;
        return @files;
    }
}

sub make_project_dir {
    my ( $self, @path ) = @_;
    my $dir = $self->generate_dir( @path );
    make_path( $dir );
}

sub serialise_layer {
    my ( $self, $layer ) = @_;
    return $self->converter->geolayer_to_layerjson( $layer );
}

sub deserialise_layer {
    my ( $self, $content ) = @_;
    return $self->converter->layerjson_to_geolayer( $content );
}

sub serialise_path {
    my ( $self, $layer ) = @_;
    return $self->converter->geopath_to_pathjson( $layer );
}

sub deserialise_path {
    my ( $self, $content ) = @_;
    return $self->converter->pathjson_to_geopath( $content );
}

sub save_file {
    my ( $self, $subdir, $file_name, $content ) = @_;

    my $dir = $self->generate_dir( $subdir );
    my $name = $dir . '/' . $file_name;

    open( my $fh, '>', $name ) || die "opening: $name: $!";
    print $fh $content;
    close $fh;
}

sub load_file {
    my ( $self, $subdir, $file_name ) = @_;

    my $dir = $self->generate_dir( $subdir );
    my $name = $dir . '/' . $file_name;

    my $content;
    open( my $fh, '<', $name ) || die "opening: $name: $!";
    while ( <$fh> ) {
        $content .= $_;
    }
    close $fh;
    return $content;
}

__PACKAGE__->meta->make_immutable;
