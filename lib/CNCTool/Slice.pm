package CNCTool::Slice;

use Moose;

use ACME::Geo::3D::3Gon;
use ACME::Geo::3D::Part;
use CAD::Format::STL;

has file => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has stl_object => (
    is => 'ro',
    isa => 'CAD::Format::STL',
    lazy => 1,
    builder => '_build_stl_object',
);

sub _build_stl_object {
    my ( $self ) = @_;
    return CAD::Format::STL->new->load( $self->file );
}

has part => (
    is => 'ro',
    isa => 'ACME::Geo::3D::Part',
    lazy => 1,
    builder => '_build_part',
);

sub _build_part {
    my ( $self ) = @_;
    my @three_gons;
    for my $facet ( $self->stl_object->part->facets ) {
        push @three_gons, ACME::Geo::3D::3Gon->new_from_points_raw_refs_with_normal( @{ $facet } );
    }
    return ACME::Geo::3D::Part->new( @three_gons );
}

sub layer_at_z {
    my ( $self, $z ) = @_;
    return $self->part->polygon_zplane_intersection( $z );
}

sub min_height {
    my ( $self ) = @_;
    my $bb = $self->part->bounding_cube;
    return $bb->minz;
}

sub max_height {
    my ( $self ) = @_;
    my $bb = $self->part->bounding_cube;
    return $bb->maxz;
}

__PACKAGE__->meta->make_immutable;
