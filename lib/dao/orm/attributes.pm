package dao::orm::attributes;

sub with {
    my ( $self, $model, $foreign_key, $local_key ) = @_;
    $self->{_models} or $self->{_models} = ();

    my $tmp = $self->$model();
    push @{ $self->{_models} }, $tmp;
    return $self;
}

our $remain;

sub _validate {
    my ( $str, $reg ) = @_;
    my $res = ( $str =~ m/$reg/ );
    $remain = $' if ($res);
    return $res;
}

sub _validate_field {
    return _validate( $_[0], '^(\w+|(`\w+`))\s*' );
}

sub _validate_value {
    return _validate( $_[0],
        '^([0-9]+|(\\\'[^,\s\"]+\\\')|(\"[^,\s\\\']+\"))\s*' );
}

sub _validate_operators {
    return _validate( $_[0], '^(=|==|!=|<|>|<>|<=|>=|!<|!>)\s*' )
      or _validate( $_[0], '^(LIKE|IS|GLOB)\s+' );
}

sub _validate_between {
    my $str = $_[0];
    _validate( $str, '^BETWEEN\s+' ) or return 0;
    _validate_value($remain)         or _validate_field($remain) or return 0;
    _validate( $remain, '^AND\s+' )  or return 0;
    _validate_value($remain)         or _validate_field($remain) or return 0;
}

sub _validate_in {
    my $str = $_[0];
    _validate( $str, '^\(\s*' );
    _validate_value($remain) or return 0;
    for ( ; ; ) {
        _validate( $remain, '^,\s*' ) or last;
        _validate_value($remain)      or return 0;
    }
    _validate( $remain, '^\)\s*' );
}

sub where {
    my ( $self, $str ) = @_;
    $self->{_db_conds} = {
        string => $str,
        params => @_,
    };

    $str =~ tr/[a-z]/[A-Z]/;    # Upcase
    $str =~ tr/^\s+//;          # Trim spaces
    $remain = $str;
    for ( ; ; ) {
        last
          unless ( _validate_field($remain) or _validate_value($remain) )
          ;                     # a or 1

        if ( _validate_operators($remain) ) {    # ==
            last
              unless ( _validate_value($remain) or _validate_field($remain) )
              ;                                  # 1 or a
            goto JOINT;
        }
        if ( _validate( $remain, '^BETWEEN\s+' ) ) {    # BETWEEN
            last
              unless ( _validate_between($remain) );    # 15 and 20
            goto JOINT;
        }
        if ( _validate( $remain, '^IN\s+' ) ) {         # IN
            last unless ( _validate_in($remain) );      # ( 1, 2, 3 )
        }
      JOINT:
        last unless _validate( $remain, '^AND\s+' );
    }

    if ( $remain ne '' ) {
        die "Unmatched WHERE clause " . $str;
    }
    return $self;
}

sub orderBy {
    my $self = shift;
    $self->{_db_order} = shift;
    $self->{_db_order} =~ /\s*\w+\s+[desc|asc]?(\s*,\s*\w+\s+[desc|asc]?)*/
      or die "Not an order by clause";
    return $self;
}

sub _num_valid {
    my $num = shift;
    return ( $num =~ /[1-9]?[0-9]+/ );
}

sub _assign {
    my ( $self, $attr, $num ) = @_;
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
