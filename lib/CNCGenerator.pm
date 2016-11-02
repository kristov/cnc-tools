package CNCGenerator;

use Moose;
use GtkZ::App;
extends 'GtkZ::App::Graphical::OpenGL';

use CAD::Format::STL;
use ACME::Geo::3D::3Gon;
use Data::Dumper;

has dotfile => (
    is => 'ro',
    isa => 'Str',
    default => '.cnc-generator',
);

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

has three_gons => (
    is => 'ro',
    isa => 'ArrayRef[ACME::Geo::3D::3Gon]',
    lazy => 1,
    builder => '_build_three_gons',
);

sub _build_three_gons {
    my ( $self ) = @_;
    my $three_gons = [];
    for my $facet ( $self->stl_object->part->facets ) {
        push @{ $three_gons }, ACME::Geo::3D::3Gon->new_from_points_raw_refs_with_normal( @{ $facet } );
    }
    return $three_gons;
}

sub corners {
    my ( $self ) = @_;

    my $three_gons = $self->three_gons;

    my $corners = [];

    for my $three_gon ( @{ $three_gons } ) {
        my $corner = {
            verticies => [],
            normal    => [ @{ $three_gon->[3] } ],
        };
        $corner->{verticies}->[0] = [ @{ $three_gon->[0]->point_a } ];
        $corner->{verticies}->[1] = [ @{ $three_gon->[1]->point_a } ];
        $corner->{verticies}->[2] = [ @{ $three_gon->[2]->point_a } ];
        $corner->{verticies}->[3] = [ @{ $three_gon->[0]->point_a } ];

        push @{ $corners }, $corner;
    }

    return $corners;
}

sub corners_old {
    my ( $self ) = @_;

    my $facets = $self->facets;

    my $corners = [];

    for my $facet ( @{ $facets } ) {
        my $corner = {
            verticies => [],
            normal    => [ @{ $facet->[0] } ],
        };
        for my $idx ( 1 .. 3 ) {
            my $vertex = $facet->[$idx];
            push @{ $corner->{verticies} }, [ @{ $vertex } ];
        }
        push @{ $corner->{verticies} }, [ @{ $facet->[1] } ];

        push @{ $corners }, $corner;
    }

    return $corners;
}

__PACKAGE__->meta->make_immutable;
