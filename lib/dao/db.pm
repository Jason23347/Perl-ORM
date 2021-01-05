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

sub excuteWithHandle {
    my ( $self, $query ) = ( shift, shift );

    my $sth = $self->_prepare($query);
    unless ( $sth->execute(@_) ) {
        warn $sth->errstr;
        return undef;
    }

    return $sth;
}

sub excuteWithReturn {
    my ( $self, $query ) = ( shift, shift );

    my $sth = $self->_prepare($query);
    my $res = $sth->execute(@_);
    unless ($res) {
        warn $sth->errstr;
        return undef;
    }

    return $res;
}

sub excute {
    my $self = shift;
    my $sth  = $self->excuteWithHandle(@_);
    return $sth->finish();
}

sub close {
    my ($self) = @_;
    $self->{_dth}->disconnect();
}

1;
