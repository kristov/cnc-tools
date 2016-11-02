package CNCTool::Logger;

use Moose;

sub debug {
    my ( $self, $template, @args ) = @_;
    $self->_message( 'debug', $template, @args );
}

sub _message {
    my ( $self, $level, $template, @args ) = @_;
    my $message = @args ? sprintf( $template, @args ) : $template;
    warn "$level: $message\n";
}

__PACKAGE__->meta->make_immutable;
