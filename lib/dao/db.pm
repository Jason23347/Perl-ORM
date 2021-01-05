package dao::db;

use DBI;

sub new {
    my $class = shift;
    if ( $#_ < 1 ) {
        die "Please assign driver and database to " . $class;
    }
    my ( $driver, $database, $user, $password ) = @_;

    my $self = { _driver => $driver, _database => $database };
    $self->{_user}     = $user     if defined $user;
    $self->{_password} = $password if defined $password;

    return bless $self, $class;
}

sub boot {
    my ($self) = @_;

    # Handler
    my $dsn = "DBI:" . $self->{_driver} . ":database=" . $self->{_database};

    # Connection
    $self->{_dth} =
      DBI->connect( $dsn, $self->{_user}, $self->{_password},
        { RaiseError => 0 } )
      or warn $DBI::errstr;

    return $self;
}

sub _prepare {
    my ( $self, $query ) = @_;

    # FIXME: Is caching necessary?
    unless ( $self->{_dth}->prepare($query) ) {
        warn "Error while excuting: " . $query;
    }
}

sub execute_handle {
    my ( $self, $query ) = ( shift, shift );

    my $sth = $self->_prepare($query);
    unless ( $sth->execute(@_) ) {
        return undef;
    }

    return $sth;
}

sub execute_array {
    my ( $self, $query ) = ( shift, shift );

    my $sth   = $self->execute_handle( $query, @_ );
    my @array = ();
    while ( $row = $sth->fetchrow_hashref() ) {
        push @array, $row;
    }
    return @array;
}

sub execute_rows_affected {
    my ( $self, $query ) = ( shift, shift );

    my $sth = $self->_prepare($query);
    my $res = $sth->execute(@_);
    unless ($res) {
        warn $sth->errstr;
        return undef;
    }

    return $res;
}

sub execute {
    my $self = shift;
    my $sth  = $self->execute_handle(@_);
    return $sth->finish();
}

sub close {
    my ($self) = @_;
    $self->{_dth}->disconnect();
}

1;
