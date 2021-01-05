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

    my $sth = $self->{_db}->excuteWithReturn(
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
      $self->{_db}->excuteWithReturn(
        "SELECT " . $fields . " FROM " . $self->{_table} . " " . $conds,
        @params );

    my @array = ();
    while ( $row = $sth->fetchrow_hashref() ) {
        push @array, $row;
    }
    $sth->finish();
    return @array;
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
    my $sth = $self->{_db}->excuteWithReturn(
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
    my ($self) = @_;
    my $primary_key = $self->{_primary_key};
    unless ( defined $self->{$primary_key} ) {
        warn "destroy failed: "
          . $primary_key
          . " not set for "
          . ( ref $self );
        return undef;
    }

    # TODO Soft delete
    return $self->{_db}->excute(
        "DELETE FROM " . $self->{_table} . " WHERE " . $primary_key . "=?",
        $self->{$primary_key} );
}

sub updateOrCreate {
    my $self  = shift;
    my $class = ref $self;
    my $orm, $db;

    if ( ( ref( $_[0] ) ) eq dao::db ) {
        $db = shift;
    }
    elsif ( $class ) {
        $db = $self->{_db};
    }

    unless ( $class ) {
        $class = $self;
    }

    $orm = $class->new($db);

    # my $orm = $self->new($db);
    foreach my $key ( keys %{$hash} ) {
        $orm->{$key} = $hash->{$key};
    }
    $orm->save();
}

sub delete {
    my ( $class, $db, $id ) = @_;
    my $orm = $class->new($db);
    $orm->{ $orm->${_primary_key} } = $id;
    $orm->destroy();
}

1;
