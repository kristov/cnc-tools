package CNCTool::Project;

use Moose;
use File::Path qw( make_path );
use CNCTool::Slice;
use CNCTool::Logger;
use Getopt::Long;
use CNCTool::Program::SliceView;
use CNCTool::Program::SliceModel;

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
            'slice-model' => 'CNCTool::Program::SliceModel',
            'slice-view'  => 'CNCTool::Program::SliceView',
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
    required => 0,
    builder => '_build_logger',
);

sub _build_logger {
    my ( $self ) = @_;
    return CNCTool::Logger->new;
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

sub make_project_dir {
    my ( $self, @path ) = @_;
    my $dir = $self->generate_dir( @path );
    make_path( $dir );
}

sub serialise {
    my ( $self, $layer ) = @_;
    use Data::Dumper;
    return Data::Dumper->new( [ $layer ], [ 'data' ] )->Indent( 1 )->Dump;
}

sub deserialise {
    my ( $self, $content ) = @_;
    my $data;
    eval "$content";
    return $data;
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
