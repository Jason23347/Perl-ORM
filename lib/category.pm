package category;

use dao::orm;
use dao::orm::relationship;

our @ISA = qw(dao::orm dao::orm::relationship);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->{_table} = 'categories';
    return bless $self, $class;
}

sub sync {
    my ($self) = @_;
    $self->_create_table(
        {
            'id'   => 'INTEGER PRIMARY KEY AUTOINCREMENT',
            'name' => 'CHAR(64) NOT NULL',
        }
    );
}

1;
