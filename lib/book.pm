package book;

use dao::orm;

our @ISA = qw(dao::orm);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    return bless $self, $class;
}

sub sync {
    my ($self) = @_;
    $self->_create_table(
        {
            'id'          => 'INTEGER PRIMARY KEY AUTOINCREMENT',
            'title'       => 'CHAR(128) NOT NULL',
            'category'    => 'CHAR(32) NOT NULL',
            'author'      => 'CHAR(64) NOT NULL',
            'status'      => 'SMALLINT DEFAULT 0',
            'last_update' => 'INTEGER NOT NULL',
            'word_count'  => 'INT NOT NULL'
        }
    );
}

1;
