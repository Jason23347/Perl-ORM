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

$book->create(
    {
        title       => "test title",
        category    => "test cate",
        author      => "test author",
        last_update => time(),
        word_count  => 5678,
    }
);

printf "insert book with id %d\n", $book->{id};

# Could be call statically too
book->create(
    $db,
    {
        title       => "hello world",
        category    => "test cate2",
        author      => "test author2",
        last_update => time(),
        word_count  => 1234,
    }
);

# Find a book with primary key: id
$book = $book->find(1) or warn "Book(1) not found";
$book->{title} .= " buff";    # Change title and save to database
$book->save();

# Fetch a list of books
my @arr = $book->get();

# Query with condition
@arr = $book->where( "title = ?", "hello world" )->get();
print Dumper(@arr);

# Update and delete
printf "%d rows with title 'hello world' deleted\n",
  $book->where( "title = ?", "hello world" )->destroy();
printf "%d rows with id %d deleted\n", $book->destroy(), $book->{id};
printf "%d rows with id %d deleted\n", $book->where( "id = ?", 2 )->destroy(),
  $book->{id};
