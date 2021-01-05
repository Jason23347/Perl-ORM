package dao::orm::query;

sub new {
    my $class = shift;
    my $self  = {};
    return bless $self, $class;
}

sub get {
    my $self = shift;

    my $fields = "";
    if ( $_[0] ) {
        foreach my $item (@_) {
            $fields .= "," . $item;
        }
        $fields =~ s/^,//;
    }
    else {
        $fields = "*";
    }

    # WHERE conditions
    my @params = ();
    my $conds  = "";
    if ( defined $self->{_conditions} ) {
        @params = $self->{_conditions}->{params};
        $conds  = "WHERE " . $self->{_conditions}->{string};
        undef $self->{_conditions};
    }

    # Do query
    my @array =
      $self->{_db}->execute_array(
        "SELECT " . $fields . " FROM " . $self->{_table} . " " . $conds,
        @params );

    # Related models
    foreach my $model ( @{ $self->{_models} } ) {

        # TODO handle related models
        my $func = $model->{handler};
        $self->$func( $model, @array );
    }
    undef $self->{_models};

    return @array;
}

sub find {
    my ( $self, $id ) = @_;

    # TODO Add limit 1
    my @list = $self->where( $self->{_primary_key} . "=?", $id )->get();
    if ( $#list lt 0 ) { return undef; }
    return $self->assign( $list[0] );
}

sub destroy {
    my ( $self, $id ) = @_;
    my $primary_key = $self->{_primary_key};
    my ( @cond_params, $cond_str );
    my $query;

    # WHERE conditions
    if ( defined $self->{_conditions} ) {
        @cond_params = $self->{_conditions}->{params};
        $cond_str    = " WHERE " . $self->{_conditions}->{string};
        undef $self->{_conditions};
        $query = "DELETE FROM " . $self->{_table} . $cond_str;
    }
    else {
        unless ( defined $self->{$primary_key} ) {
            warn "orm "
              . ( ref $self )
              . " destroy failed: Please specify where condition or assign "
              . $primary_key;
            return undef;
        }
        $query =
          "DELETE FROM " . $self->{_table} . " WHERE " . $primary_key . "=?";
        push @cond_params, $self->{$primary_key};
    }

    # TODO Soft delete
    return $self->{_db}->execute_rows_affected( $query, @cond_params );
}

sub update {
    my ( $self, $hash ) = @_;
    unless ( %{$hash} ) {
        warn "Empty hash";
        return 0;
    }

    # WHERE conditions
    my ( @cond_params, $cond_str );
    if ( defined $self->{_conditions} ) {
        @cond_params = $self->{_conditions}->{params};
        $cond_str    = " WHERE " . $self->{_conditions}->{string};
        undef $self->{_conditions};
    }

    my $query       = "";
    my @values      = ();
    my $primary_key = $self->{_primary_key};
    foreach my $key ( keys %{$hash} ) {
        unless ( $key =~ /^_|^$primary_key\$|^\$/ ) {
            $query .= ",`$key`=?";
            push @values, $hash->{$key};
        }
    }
    $query =~ s/^,//;
    $query = "UPDATE " . $self->{_table} . " set " . $query . $cond_str;
    printf "%s\n", $query;
    $self->{_db}->execute( $query, @values, @cond_params );
}

1;