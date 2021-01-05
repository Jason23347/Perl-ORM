package dao::orm::attributes;

sub new {
    my $class = shift;
    my $self  = {};
    return bless $self, $class;
}

sub with {
    my ( $self, $model, $foreign_key, $local_key ) = @_;
    $self->{_models} or $self->{_models} = ();

    my $tmp = $self->$model();
    push @{ $self->{_models} }, $tmp;
    return $self;
}

sub where {
    my $self = shift;
    $self->{_conditions} = {
        string => shift,
        params => @_,
    };
    return $self;
}

1;
