package dao::orm;

use strict 'vars';

sub _default_table_name {

    # Use class name by default
    my ($class) = @_;
    my @list    = split( /:+/, $class );
    my $table   = $list[$#list];

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
    return $self->{_db}->execute(
        "CREATE TABLE IF NOT EXISTS " . $self->{_table} . '(' . $str . ')' );
}

sub with {
    my ( $self, $model, $foreign_key, $local_key ) = @_;
    $self->{_models} or $self->{_models} = ();

    my $tmp = $self->$model();
    push @{ $self->{_models} }, $tmp;
    return $self;
}

sub find {
    my ( $self, $id ) = @_;

    # TODO Add limit 1
    my @list = $self->where( $self->{_primary_key} . "=?", $id )->get();
    if ( $#list lt 0 ) { return undef; }
    return $self->assign( $list[0] );
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

    my $fields = "";
    if ($_[0]) {
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

sub assign {
    my ( $self, $hash ) = @_;
    foreach my $key ( keys %{$hash} ) {
        unless ( $key =~ /^_/ ) {
            $self->{$key} = $hash->{$key};
        }
    }
    return $self;
}

sub save {
    my $self = shift;

    my $primary_key = $self->{_primary_key};
    my $id          = $self->{$primary_key};

    my $query  = "";
    my @values = ();
    if ( defined $id ) {    # Update or insert
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
        $self->{_db}->execute( $query, @values, $id );
        return $self;
    }

    my $fields = "";
    my $list   = "";

    @values = ();
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
    my $sth = $self->{_db}->execute_handle(
        "INSERT INTO "
          . $self->{_table} . " ("
          . $fields
          . ") VALUES ("
          . $list . ")",
        @values
    );
    $self->{$primary_key} = $sth->last_insert_id();
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

sub create {
    my $self  = shift;
    my $class = ref $self;
    my ( $orm, $db );

    undef $self->{ $self->{_primary_key} };

    if ( ( ref( $_[0] ) ) eq 'dao::db' ) {
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
