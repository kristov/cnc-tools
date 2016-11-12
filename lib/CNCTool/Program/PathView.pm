package CNCTool::Program::PathView;

use Moose;
use GtkZ::App;
extends 'GtkZ::App::Graphical::Cairo';

sub options {
    return [
        {
            name    => 'path_file',
            type    => 'file',
            req     => 1,
            desc    => 'Path file to render',
        },
        {
            name    => 'show_parallel',
            type    => 'bool',
            req     => 0,
            desc    => 'Render the parallel path',
        },
        {
            name    => 'flip_parallel',
            type    => 'bool',
            req     => 0,
            desc    => 'Flip the parallel path',
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

has path_file => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has show_points => (
    is => 'ro',
    isa => 'Bool',
    required => 0,
    default => 0,
);

has flip_parallel => (
    is => 'ro',
    isa => 'Bool',
    required => 0,
    default => 0,
);

has path => (
    is => 'rw',
    isa => 'ACME::Geo::Path',
    lazy => 1,
    builder => '_build_path',
);

sub _build_path {
    my ( $self ) = @_;
    return $self->project->deserialise_path( $self->load_file( $self->path_file ) );
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

            my $path = $self->path;
            my $scale = $self->calculate_scale( $path->bounding_box );

            my $R = 0;
            my $G = 1;

            my $bbox = $path->bounding_box;
            my $dx = $bbox->maxx - $bbox->minx;
            my $dy = $bbox->maxy - $bbox->miny;

            if ( $dx == 0 && $dy == 0 ) {
                $self->project->logger->debug( 'not rendering empty path' );
                next PATH;
            }

            my $offset = 0;

            $cr->set_line_width( 2 );
            $cr->set_source_rgb( 0, 1, 0 );
            $self->render_path( $cr, $path, $scale, $offset );

            my $parallel = $path->parallel_path( $self->flip_parallel );
            $cr->set_line_width( 1 );
            $cr->set_source_rgb( 0, 1, 1 );
            $self->render_path( $cr, $parallel, $scale, $offset );

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

            $cr->restore;
        },
    ];
}

sub render_path {
    my ( $self, $cr, $path, $scale, $offset ) = @_;

    for my $line ( @{ $path } ) {
        my $xs = ( $line->start->X * $scale ) + $offset;
        my $ys = ( $line->start->Y * $scale ) + $offset;
        my $xe = ( $line->end->X * $scale ) + $offset;
        my $ye = ( $line->end->Y * $scale ) + $offset;
        $cr->move_to( $xs, $ys );
        $cr->line_to( $xe, $ye );
    }
    $cr->stroke();
}

__PACKAGE__->meta->make_immutable;
