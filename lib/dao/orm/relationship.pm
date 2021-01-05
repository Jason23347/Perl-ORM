package dao::orm::relationship;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = {};
    return bless $self, $class;
}

sub hasOne {
    my ( $self, $model, $foreign_key, $local_key ) = @_;

    sub default_local_key { shift . '_id' }
    return {
        relationHandler => 'hasOneRelationHandler',
        model           => $model,
        foreign_key     => (
            $foreign_key
              or 'id'
        ),
        local_key => (
            $local_key
              or default_local_key($model)
        )
    };
}

sub hasOneRelationHandler {
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
    my @model_list = $self->{_db}->excuteReturnArray(
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
                continue;
            }
            $orm->{ $model->{model} } = $tmp;
            last;
        }
    }
}

1;
