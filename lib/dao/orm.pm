package dao::orm;

use dao::orm::attributes;
use dao::orm::query;

our @ISA = qw(dao::orm::attributes dao::orm::query);

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
