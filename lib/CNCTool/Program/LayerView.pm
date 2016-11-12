package CNCTool::Program::SliceView;

use Moose;
use GtkZ::App;
extends 'GtkZ::App::Graphical::Cairo';

use ACME::Geo::3D::3Gon;
use ACME::Geo::3D::Part;

sub options {
    return [
        {
            name    => 'stl_file',
            type    => 'file',
            req     => 0,
            desc    => 'STL file to slice',
        },
        {
            name    => 'z',
            type    => 'decimal',
            req     => 0,
            desc    => 'The Z axis height to view the slice',
        },
        {
            name    => 'cycle',
            type    => 'bool',
            req     => 0,
            desc    => 'Cycle through layers',
        },
        {
            name    => 'show_points',
            type    => 'bool',
            req     => 0,
            desc    => 'Render the points too',
        },
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
    required => 0,
);

has z => (
    is => 'ro',
    isa => 'Num',
    required => 0,
);

has cycle => (
    is => 'ro',
    isa => 'Bool',
    required => 0,
);

has show_points => (
    is => 'ro',
    isa => 'Bool',
    required => 0,
);

has stl_object => (
    is => 'ro',
    isa => 'CAD::Format::STL',
    lazy => 1,
    builder => '_build_stl_object',
);

sub _build_stl_object {
    my ( $self ) = @_;
    return CAD::Format::STL->new->load( $self->stl_file );
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
        my $file_name = sprintf( '%0.5f.layer', $z );
        $self->project->logger->debug( 'found %s', $file_name );
        my $content = $self->project->load_file( 'raw_layer_files', $file_name );
        return $self->project->deserialise_layer( $content );
    }
    else {
        return $self->part->polygon_zplane_intersection( $self->z );
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

sub BUILD {
    my ( $self ) = @_;

    if ( !$self->cycle && !defined $self->z ) {
        die "cycle and z not defined";
    }

    if ( $self->cycle ) {
        Glib::Timeout->add( 300, sub { $self->load_next_layer( @_ ) }, $self->da );
    }
}

sub load_next_layer {
    my ( $self ) = @_;
    my $file_name = shift @{ $self->layer_files };
    return unless $file_name;
    $self->project->logger->debug( $file_name );
    my $content = $self->project->load_file( 'raw_layer_files', $file_name );
    $self->layer( $self->project->deserialise_layer( $content ) );
    $self->invalidate_da;
    return 1;
}

sub calculate_scale {
    my ( $self, $bbox ) = @_;

    my $minx = $bbox->minx;
    my $maxx = $bbox->maxx;
    my $miny = $bbox->miny;
    my $maxy = $bbox->maxy;

    my $width = $self->da_width - 40;
    my $height = $self->da_height - 40;

    my $dx = $maxx - $minx;
    my $dy = $maxy - $miny;

    my $scale = 1;
    if ( $dy > $dx ) {
        $scale = $height / $dy;
    }
    else {
        $scale = $width / $dx;
    }
    return $scale;
}

sub layer_renderers {
    my ( $self ) = @_;
    return [
        sub {
            my ( $self, $cr ) = @_;
            $cr->save;

            my $layer = $self->layer;
            my $scale = $self->calculate_scale( $layer->bounding_box );

            my $R = 0;
            my $G = 1;

            PATH: for my $path ( @{ $layer } ) {

                my $bbox = $path->bounding_box;
                my $dx = $bbox->maxx - $bbox->minx;
                my $dy = $bbox->maxy - $bbox->miny;

                if ( $dx == 0 && $dy == 0 ) {
                    next PATH;
                }
                print sprintf( '%0.4f, %0.4f', $dx, $dy ) . "\n";

                $cr->set_line_width( 2 );
                $cr->set_source_rgb( $R, $G, 0 );

                $R = ( $R == 0 ) ? 1 : 0;
                $G = ( $G == 0 ) ? 1 : 0;


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

                if ( $self->show_points ) {
                    $cr->set_line_width( 1 );
                    $cr->set_source_rgb( 1, 0, 0 );

                    for my $line ( @{ $path } ) {
                        my $xs = ( $line->start->X * $scale ) + $offset;
                        my $ys = ( $line->start->Y * $scale ) + $offset;
                        $cr->rectangle( $xs - 2, $ys - 2, 4, 4 );
                    }
                    $cr->stroke();
                }
            }

            $cr->restore;
        },
    ];
}

__PACKAGE__->meta->make_immutable;
