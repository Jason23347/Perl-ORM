#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

use File::Basename;
use lib dirname(__FILE__) . '/lib';

use dao::db;
use book;

# Create database connection at first
our $db = dao::db->new( "SQLite", "database.db" )->boot();
my $book = book->new($db);    # Create an orm object
$book->sync();                # Ensure the table exists

$book->updateOrCreate(
    {
        # id          => 1,                    # unset to update
        title       => "test title",
        category    => "test cate",
        author      => "test author",
        last_update => time(),
        word_count  => 12345678,
    }
);

# Could be call statically
book->updateOrCreate(
    $db,
    {
        id    => 1,
        title => "hello world",
    }
);

# Find a book with primary key: id
$book = $book->find(1) or warn "Book(1) not found";
$book->{title} .= " buff";    # Change title and save to database
$book->save();

# Fetch a list of books
my @arr = $book->get();

# Query with condition
@arr = $book->where( "word_count = ?", 12345678 )->get();
print Dumper(@arr);
