package dao::orm;

sub _default_table_name {

    # Use class name by default
    my ($class) = @_;
    my @list    = split( /:+/, $class );
    my $table   = @list[$#list];

    # Convert 'Ab' into '_ab'
    while ( $table =~ /[A-Z][a-z]/ ) {
        my $str = $&;
        $str   =~ tr/[A-Z]/[a-z]/;
        $table =~ s/$&/_$str/;
    }

    # Convert 'CGI' into '_cgi'
    while ( $table =~ /[A-Z][A-Z]+/ ) {
        my $str = $&;
        $str   =~ tr/[A-Z]/[a-z]/;
        $table =~ s/$&/_$str/;
    }

    # Trim underlines
    $table =~ s/^_+|_+$//;

    # Remove duplicated underlines
    $table =~ s/__+|_//;

    return $table . 's';
}

sub new {
    my $class = shift;
    my $self->{_db} = shift or die "No db assigned to orm " . $class;

    $self->{_primary_key} = 'id';
    $self->{_table}       = $class->_default_table_name();

    return bless $self, $class;
}

sub _create_table {
    my ( $self, $hash ) = @_;

    my $str = "";
    foreach my $key ( keys %{$hash} ) {
        $str .= '"' . $key . '" ' . $hash->{$key} . ',';
    }
    $str =~ s/,$//;
    return $self->{_db}->excute(
        "CREATE TABLE IF NOT EXISTS " . $self->{_table} . '(' . $str . ')' );
}

sub find {
    my ( $self, $key ) = @_;

    my $sth = $self->{_db}->excuteWithHandle(
        "SELECT * from "
          . $self->{_table}
          . " where "
          . $self->{_primary_key}
          . " =? LIMIT 1",
        $key
    );

    my @status;
    my $hash = $sth->fetchrow_hashref or return 0;
    for my $key ( keys %{$hash} ) {
        $self->{$key} = $hash->{$key};
    }

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

sub get {
    my $self = shift;
    my @list = @_;

    my $fields = "";
    if ( defined $list ) {
        foreach my $item ( @{$list} ) {
            $fields .= "," . $item;
        }
        $fields =~ s/^,//;
    }
    else {
        $fields = "*";
    }

    # Load WHERE conditions
    my @params = (), $conds = "";
    if ( defined $self->{_conditions} ) {
        @params = $self->{_conditions}->{params};
        $conds  = "WHERE " . $self->{_conditions}->{string};
        undef $self->{_conditions};
    }

    my $sth =
      $self->{_db}->excuteWithHandle(
        "SELECT " . $fields . " FROM " . $self->{_table} . " " . $conds,
        @params );

    my @array = ();
    while ( $row = $sth->fetchrow_hashref() ) {
        push @array, $row;
    }
    $sth->finish();
    return @array;
}

sub assign {
    my ( $self, $hash ) = @_;
    foreach my $key ( keys %{$hash} ) {
        $self->{$key} = $hash->{$key};
    }
}

sub save {
    my $self = shift;

    my $primary_key = $self->{_primary_key};
    $id = $self->{$primary_key};
    if ( defined $id ) {    # Update or insert
        my $qyery  = "";
        my @values = ();
        foreach my $key ( keys %{$self} ) {
            unless ( $key =~ /^_|^$primary_key\$|^\$/ ) {
                $query .= ",`$key`=?";
                push @values, $self->{$key};
            }
        }
        $query =~ s/^,//;
        $query =
            "UPDATE "
          . $self->{_table} . " set "
          . $query
          . " WHERE "
          . $primary_key . "=?";
        $self->{_db}->excute( $query, @values, $id );
        return $self;
    }

    my $fields = "";
    my $list   = "";
    my @values = ();
    foreach my $key ( keys %{$self} ) {
        unless ( $key =~ /^_/ ) {
            my $value = $self->{$key};

            $fields .= "," . $key;
            $list   .= ",?";
            push @values, ( defined $value ) ? $value : 'NULL';
        }
    }
    $fields =~ s/^,//;
    $list   =~ s/^,//;
    my $sth = $self->{_db}->excuteWithHandle(
        "INSERT INTO "
          . $self->{_table} . " ("
          . $fields
          . ") VALUES ("
          . $list . ")",
        @values
    );
    $self->{$primary_key} = $sth->last_insert_id();
    $sth->finish();
}

sub destroy {
    my ( $self, $id ) = @_;
    my $primary_key = $self->{_primary_key};
    my @cond_params, $cond_str;
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
    return $self->{_db}->excuteWithReturn( $query, @cond_params );
}

sub update {
    my ( $self, $hash ) = @_;
    unless ( %{$hash} ) {
        warn "Empty hash";
        return 0;
    }

    # WHERE conditions
    my @cond_params, $cond_str;
    if ( defined $self->{_conditions} ) {
        @cond_params = $self->{_conditions}->{params};
        $cond_str    = " WHERE " . $self->{_conditions}->{string};
        undef $self->{_conditions};
    }

    my $qyery  = "";
    my @values = ();
    foreach my $key ( keys %{$hash} ) {
        unless ( $key =~ /^_|^$primary_key\$|^\$/ ) {
            $query .= ",`$key`=?";
            push @values, $hash->{$key};
        }
    }
    $query =~ s/^,//;
    $query = "UPDATE " . $self->{_table} . " set " . $query . $cond_str;
    printf "%s\n", $query;
    $self->{_db}->excute( $query, @values, @cond_params );
}

sub create {
    my $self  = shift;
    my $class = ref $self;
    my $orm, $db;

    undef $self->{ $self->{_primary_key} };

    if ( ( ref( $_[0] ) ) eq dao::db ) {
        $db = shift;
    }
    elsif ($class) {
        $db = $self->{_db};
    }

    unless ($class) {
        $class = $self;
    }

    $orm = $class->new($db);

    my $hash = shift;
    $orm->assign($hash);
    $orm->save();

    if ( ref($self) ) {
        $self->assign($orm);
        undef $orm;
    }
}

1;
