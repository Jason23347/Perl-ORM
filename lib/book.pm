package book;

use dao::orm;
use dao::orm::relationship;

our @ISA = qw(dao::orm dao::orm::relationship);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    return bless $self, $class;
}

sub author {
    my $self = shift;
    return $self->hasOne( author, 'id', 'author_id' );
}

sub sync {
    my ($self) = @_;
    $self->_create_table(
        {
            'id'          => 'INTEGER PRIMARY KEY AUTOINCREMENT',
            'title'       => 'CHAR(128) NOT NULL',
            'category'    => 'INTEGER NOT NULL',
            'author_id'   => 'INTEGER NOT NULL',
            'status'      => 'SMALLINT DEFAULT 0',
            'last_update' => 'INTEGER NOT NULL',
            'word_count'  => 'INT NOT NULL'
        }
    );
}

1;
