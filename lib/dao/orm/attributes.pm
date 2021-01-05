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

sub _num_valid {
    my $num = shift;
    return ( $num =~ /[1-9]?[0-9]+/ );
}

sub _assign {
    my ( $self, $attr, $num ) = @_;
    printf "%s %s %d\n", $self, $attr, $num;
    _num_valid($num)
      or die "Cannot set " . $attr . " to " . $num;

    $self->{ "_db_" . $attr } = $num;
    return $self;
}

sub limit {
    _assign( shift, 'limit', shift );
}

sub offset {
    _assign( shift, 'offset', shift );
}

1;
