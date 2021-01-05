package dao::orm::relationship;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = {};
    return bless $self, $class;
}

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
    my $class       = $model->{model}->new( $self->{_db} );
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
          . $class->{_table}
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
    my $class       = $model->{model}->new( $self->{_db} );
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
          . $class->{_table}
          . " WHERE "
          . $foreign_key . " in ("
          . $id_query . ")",
        @id_list
    );

    # TODO Optimize
    foreach my $orm (@array) {
        my @list = ();
        foreach my $tmp (@model_list) {
            if ( $orm->{$local_key} eq $tmp->{$foreign_key} ) {
                push @list, $tmp;
            }
        }
        $orm->{ $model->{attr} } = \@list;
    }
}

1;
