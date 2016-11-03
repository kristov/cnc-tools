package CNCGenerator::SliceView;

use Moose;
use GtkZ::App;
extends 'GtkZ::App::Graphical::Cairo';

use ACME::Geo::3D::3Gon;
use ACME::Geo::3D::Part;
use CAD::Format::STL;

has file => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has z => (
    is => 'ro',
    isa => 'Num',
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

has layer => (
    is => 'ro',
    isa => 'ACME::Geo::Layer',
    lazy => 1,
    builder => '_build_layer',
);

sub _build_layer {
    my ( $self ) = @_;
    my $layer = $self->part->polygon_zplane_intersection( $self->z );
    return $layer;
}

has min_max_bounds => (
    is => 'rw',
    isa => 'ArrayRef',
    required => 0,
);

sub layer_renderers {
    my ( $self ) = @_;
    return [
        sub {
            my ( $self, $cr ) = @_;
            $cr->save;

            my $layer = $self->layer;
            for my $path ( @{ $layer } ) {

                $cr->set_line_width( 2 );
                $cr->set_source_rgb( 0, 1, 0 );

                my $scale = 40;
                my $offset = 20;

                for my $line ( @{ $path } ) {
                    my $xs = ( $line->start->X * $scale ) + $offset;
                    my $ys = ( $line->start->Y * $scale ) + $offset;
                    my $xe = ( $line->end->X * $scale ) + $offset;
                    my $ye = ( $line->end->Y * $scale ) + $offset;
                    $cr->move_to( $xs, $ys );
                    $cr->line_to( $xe, $ye );
                }
                $cr->stroke();

                $cr->set_source_rgb( 1, 0, 0 );

                for my $line ( @{ $path } ) {
                    my $xs = ( $line->start->X * $scale ) + $offset;
                    my $ys = ( $line->start->Y * $scale ) + $offset;
                    $cr->rectangle( $xs - 5, $ys - 5, 10, 10 );
                }
                $cr->stroke();
            }

            $cr->restore;
        },
    ];
}

__PACKAGE__->meta->make_immutable;
