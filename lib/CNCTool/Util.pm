package CNCTool::Util;

use Moose;
use File::Path qw();
use Data::Dumper;
use CNCTool::Logger;
use CNCTool::GcodeGen;
use ACME::Geo::Util::Converter;

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

has gcodegen => (
    is => 'ro',
    isa => 'CNCTool::GcodeGen',
    lazy => 1,
    builder => '_build_gcodegen',
);

sub _build_gcodegen {
    my ( $self ) = @_;
    return CNCTool::GcodeGen->new;
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

sub load_layer_file {
    my ( $self, $opts ) = @_;
    return $self->deserialise_layer( $self->load_file( $opts->{file} ) );
}

sub load_path_file {
    my ( $self, $opts ) = @_;
    return $self->deserialise_path( $self->load_file( $opts->{file} ) );
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
    my ( $self, $path ) = @_;
    return $self->converter->geopath_to_pathjson( $path );
}

sub serialise_point {
    my ( $self, $point ) = @_;
    return $self->converter->geopoint_to_pointjson( $point );
}

sub deserialise_path {
    my ( $self, $content ) = @_;
    return $self->converter->pathjson_to_geopath( $content );
}

sub load_pointlist_file {
    my ( $self, $opts ) = @_;
    return $self->converter->json->decode( $self->load_file( $opts->{file} ) );
}

sub build_gcode_from_pointlist {
    my ( $self, $pointlist, $depth ) = @_;

    return $self->gcodegen->pointlist_to_drill( $pointlist, $depth );
}

sub build_gcode_from_path {
    my ( $self, $path, $name, $depth ) = @_;

    my $raw = $self->converter->serialise_path( $path );

    return $self->gcodegen->linerefs_to_gcode( $raw, $name, $depth );
}

sub load_file {
    my ( $self, $file_name ) = @_;

    my $content;
    open( my $fh, '<', $file_name ) || die "opening: $file_name: $!";
    while ( <$fh> ) {
        $content .= $_;
    }
    close $fh;
    return $content;
}

sub save_file {
    my ( $self, $file_name, $content ) = @_;

    open( my $fh, '>', $file_name ) || die "opening: $file_name: $!";
    print $fh $content;
    close $fh;
}

sub make_path {
    my ( $self, $dir ) = @_;
    File::Path::make_path( $dir );
}

sub dump {
    my ( $self, $data ) = @_;
    my @keys = sort { $a cmp $b } keys %{ $data };
    my @vals;
    for my $key ( @keys ) {
        push @vals, $data->{$key};
    }
    print Data::Dumper->new( \@vals, \@keys )->Indent( 1 )->Quotekeys( 0 )->Dump;
}

__PACKAGE__->meta->make_immutable;
