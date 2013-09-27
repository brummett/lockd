package AnyEventHandleFake;

sub new {
    my $class = shift;
    my %params = @_;
    return bless \%params, $class;
}


sub push_read {
    my($self, $type, $sub) = @_;

    Carp::croak("push_read called with type $type") unless $type eq 'json';

    push @{ $self->{queued_reads} ||= []}, $sub;
    $self->_run_queued_reads;
}

sub _run_queued_reads {
    my $self = shift;
    my $input_buffer = $self->{input_buffer} ||= [];
    my $queued_reads = $self->{queued_reads} ||= [];

    while (@$input_buffer and @$queued_reads) {
        my $msg = shift @$input_buffer;
        my $cb = shift @$queued_reads;
        $self->$cb( $msg );
    }
}

sub push_write {
    my($self, $type, $msg) = @_;
    Carp::croak("push_read called with type $type") unless $type eq 'json';

    push @{ $self->{output_buffer} ||= []}, $msg;
}

sub _queue_input {
    my $self = shift;
    my $msg = shift;
    push @{ $self->{input_buffer} ||= []}, $msg;
    $self->_run_queued_reads;
}

sub _written_data {
    my $self = shift;
    my $output = $self->{output_buffer} || [];
    $self->{output_buffer} = [];
    return $output;
}

1;
