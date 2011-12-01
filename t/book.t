use strict;
use warnings;
use Test::More;
use lib 't/lib';

use_ok( 'HTML::FormHandler' );

use_ok( 'BookDB::Form::Book');

use_ok( 'BookDB::Schema');

my $schema = BookDB::Schema->connect('dbi:SQLite:t/db/book.db');
ok($schema, 'get db schema');

my $item = $schema->resultset('Book')->new_result({});
my $form = BookDB::Form::Book->new;

ok( !$form->process( item => $item ), 'Empty data' );

# This is munging up the equivalent of param data from a form
my $good = {
    'title' => 'How to Test Perl Form Processors',
    'authors' => [5],
    'genres' => [2, 4],
    'format'       => 2,
    'isbn'   => '123-02345-0502-2' ,
    'publisher' => 'EreWhon Publishing',
    'user_updated' => 1,
    'comment' => 'this is a comment',
};

ok( $form->process( item => $item, params => $good ), 'Good data' );

my $book = $form->item;
END { $book->delete };

ok ($book, 'get book object from form');

is( $book->extra, 'this is a comment', 'comment exists' );
is_deeply( $form->values, $good, 'values correct' );
$good->{$_} = '' for qw/ year pages/;
is_deeply( $form->fif, $good, 'fif correct' );

my $num_genres = $book->genres->count;
is( $num_genres, 2, 'multiple select list updated ok');

is( $form->field('format')->value, 2, 'get value for format' );

$good->{genres} = 2;
ok( $form->process($good), 'handle one value for multiple select' );
is_deeply( $form->field('genres')->value, [2], 'right value for genres' );

my $id = $book->id;

$good->{authors} = [];
$good->{genres} = [2,4];
$form->process($good);

is_deeply( $form->field('authors')->value, [], 'author value right in form');
is( $form->field('publisher')->value, 'EreWhon Publishing', 'right publisher');

my $value_hash = { %{$good},
                   authors => [],
                   year => undef,
                   pages => undef
                 };
delete $value_hash->{submit};
is_deeply( $form->values, $value_hash, 'get right values from form');

my $bad_1 = {
    notitle => 'not req',
    silly_field   => 4,
};

ok( !$form->process( $bad_1 ), 'bad 1' );

$form = BookDB::Form::Book->new(item => $book, schema => $schema);
ok( $form, 'create form from db object');

my $genres_field = $form->field('genres');
is_deeply( sort $genres_field->value, [2, 4], 'value of multiple field is correct');

my $bad_2 = {
    'title' => "Another Silly Test Book",
    'authors' => [6],
    'year' => '1590',
    'pages' => 'too few',
    'format' => '22',
};

ok( !$form->process( $bad_2 ), 'bad 2');
ok( $form->field('year')->has_errors, 'year has error' );
ok( $form->field('pages')->has_errors, 'pages has error' );
ok( !$form->field('authors')->has_errors, 'author has no error' );
ok( $form->field('format')->has_errors, 'format has error' );

my $values = $form->value;
$values->{year} = 1999;
$values->{pages} = 101;
$values->{format} = 2;
my $validated = $form->validate( $values );
ok( $validated, 'now form validates' );

$form->process;
is( $book->publisher, 'EreWhon Publishing', 'publisher has not changed');

# test that multiple fields (genres) with value of [] deletes genres
is( $book->genres->count, 2, 'multiple select list updated ok');
$good->{genres} = [];
$form->process( $good );
is( $book->genres->count, 0, 'multiple select list has no selected options');

$form = BookDB::Form::Book->new(schema => $schema, active_column => 'is_active');
is( scalar @{$form->field( 'genres' )->options}, 0, 'active_column test' );

{
    package Test::Book;
    use HTML::FormHandler::Moose;
    extends 'HTML::FormHandler::Model::DBIC';

    has_field 'title' => ( minlength => 3, maxlength => 40, required => 1 );
    has_field 'year';
    has_field 'submit' => ( type => 'Submit' );
}

# this tests to make sure that result loaded from db object is cleared when
# the result is then loaded from the params
$form = Test::Book->new;
my $new_book = $schema->resultset('Book')->new_result({});
$form->process( item => $new_book, params => {} );
$form->process( item => $new_book, params => { title => 'abc' } );
is( $form->result->num_results, 3, 'right number of results');

done_testing;
