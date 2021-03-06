package dao::orm::relationship;

use strict;
use warnings;

sub default_key {
    shift . '_id';
}

sub hasOne {
    my ( $self, $model, $foreign_key, $local_key ) = @_;

    return {
        handler     => 'hasOneHandler',
        model       => $model,
        foreign_key => (
            $foreign_key
              or 'id'
        ),
        local_key => (
            $local_key
              or default_key($model)
        )
    };
}

sub hasOneHandler {
    my ( $self, $model, @array ) = @_;
    my $other       = $model->{model}->new( $self->{_db} );
    my $local_key   = $model->{local_key};
    my $foreign_key = $model->{foreign_key};
    my $primary_key = $self->{_primary_key};

    my $id_query = "";
    my @id_list  = ();
    foreach my $orm (@array) {
        $id_query .= ",?";
        push @id_list, $orm->{$local_key};
    }
    $id_query =~ s/^,//;

    # Query related models
    my @model_list = $self->{_db}->execute_array(
        "SELECT * FROM "
          . $other->{_table}
          . " WHERE "
          . $foreign_key . " in ("
          . $id_query . ")",
        @id_list
    );

    # TODO Optimize
    foreach my $tmp (@model_list) {
        foreach my $orm (@array) {
            unless ( $orm->{$local_key} eq $tmp->{$foreign_key} ) {
                next;
            }
            $orm->{ $model->{model} } = $tmp;
            last;
        }
    }
}

sub hasMany {
    my ( $self, $model, $attr, $foreign_key, $local_key ) = @_;
    $attr
      or die "Relationship attribute not specified ("
      . ( ref $self ) . " <- "
      . $model . ")";

    return {
        handler   => 'hasManyHandler',
        model     => $model,
        attr      => $attr,
        local_key => (
                 $local_key
              or $self->{_primary_key}
        ),
        foreign_key => (
            $foreign_key
              or default_key( ref $self )
        )
    };
}

sub hasManyHandler {
    my ( $self, $model, @array ) = @_;
    my $other       = $model->{model}->new( $self->{_db} );
    my $local_key   = $model->{local_key};
    my $foreign_key = $model->{foreign_key};

    my $id_query = "";
    my @id_list  = ();
    foreach my $orm (@array) {
        $id_query .= ",?";
        push @id_list, $orm->{$local_key};
    }
    $id_query =~ s/^,//;

    # Query related models
    my @model_list = $self->{_db}->execute_array(
        "SELECT * FROM "
          . $other->{_table}
          . " WHERE "
          . $foreign_key . " in ("
          . $id_query . ")",
        @id_list
    );

    # TODO Optimize
    foreach my $orm (@array) {
        my $list = ();
        foreach my $tmp (@model_list) {
            if ( $orm->{$local_key} eq $tmp->{$foreign_key} ) {
                push @{$list}, $tmp;
            }
        }
        $orm->{ $model->{attr} } = $list;
    }
}

sub manyToMany {
    my ( $self, $model, $attr, $table, $foreign_key, $local_key ) = @_;
    $table
      or die "Adjecency table not specified ("
      . ( ref $self ) . " <-> "
      . $model . ")";

    return {
        handler   => 'manyToManyHandler',
        model     => $model,
        table     => $table,
        attr      => $attr,
        local_key => (
            $local_key
              or default_key( ref $self )
        ),
        foreign_key => (
            $foreign_key
              or default_key( ref $model )
        )
    };
}

sub _array_to_hash {
    my ( $key, @array ) = @_;
    my %hash = ();
    foreach my $item (@array) {
        $hash{ $item->{$key} } = \$item;
    }
    return %hash;
}

sub manyToManyHandler {
    my ( $self, $hash, @array ) = @_;
    my $other       = $hash->{model}->new( $self->{_db} );
    my $local_key   = $hash->{local_key};
    my $foreign_key = $hash->{foreign_key};
    my $primary_key = $self->{_primary_key};
    my $other_key   = $other->{_primary_key};

    my $id_query = "";
    my @id_list  = ();
    foreach my $orm (@array) {
        $id_query .= ",?";
        push @id_list, $orm->{$primary_key};
    }
    $id_query =~ s/^,//;

    # Query adjeceny table
    my @tmp_list = $self->{_db}->execute_array(
        "SELECT * FROM "
          . $hash->{table}
          . " WHERE "
          . $local_key . " in ("
          . $id_query . ")",
        @id_list
    );

    $id_query = "";
    @id_list  = ();
    foreach my $orm (@tmp_list) {
        $id_query .= ",?";
        push @id_list, $orm->{$foreign_key};
    }
    $id_query =~ s/^,//;

    # Query related models
    my @model_list = $self->{_db}->execute_array(
        "SELECT * FROM "
          . $other->{_table}
          . " WHERE "
          . $other->{_primary_key} . " in ("
          . $id_query . ")",
        @id_list
    );

    my $table;
    foreach my $tmp (@tmp_list) {
        my $local   = $tmp->{$local_key};
        my $foreign = $tmp->{$foreign_key};
        my $list    = \$table->{$local};
        push @$$list, $foreign;
    }

    my %orm_hash   = _array_to_hash( $primary_key, @array );
    my %model_hash = _array_to_hash( $other_key,   @model_list );

    foreach my $orm (@array) {
        my $list = \$orm->{ $hash->{attr} };
        $$list = ();
        my @key_list = $table->{ $orm->{$primary_key} };
        foreach my $keys (@key_list) {
            foreach my $key (@$keys) {
                my $tmp = $model_hash{$key};
                push @$$list, $$tmp;
            }
        }
    }
}

1;
