use strict;
use warnings;
use Test::More;
use lib 't/lib';

use_ok( 'HTML::FormHandler' );

use_ok( 'BookDB::Form::Book');

use_ok( 'BookDB::Schema');

my $schema = BookDB::Schema->connect('dbi:SQLite:t/db/book.db');
ok($schema, 'get db schema');

my $book = $schema->resultset('Book')->create(
   {  title => 'Testing form',
      isbn => '02340994',
      publisher => 'NoWhere',
      pages => '702',
   });
END { $book->delete }

ok( $book, 'get book');

my $form = BookDB::Form::Book->new(item => $book );
ok( $form, 'create form from db object');

is( $form->field('pages')->fif, 702, 'get field fif value' );

is( $form->field('publisher')->fif, 'NoWhere', 'get another field fif value' );

my $fif = $form->fif;

is_deeply( $fif, {
      title => 'Testing form',
      isbn => '02340994',
      publisher => 'NoWhere',
      pages => '702',
      comment => '',
      format => '',
      year => '',
      user_updated => 0,
   }, 'get form fif' );

$fif->{pages} = '501';
$form = BookDB::Form::Book->new(item => $book, schema => $schema, params => $fif);
ok( $form, 'use params parameters on new' );

is( $form->field('pages')->fif, 702, 'get field fif value' );

is( $form->get_param('pages'), '501', 'params contains new value' );

is( $form->field('year')->fif, '', 'get another field fif value' );
$form->processed(0);

my $validated = $form->process;

ok( $validated, 'validated without params' );

is( $form->field('publisher')->fif, 'NoWhere', 'get field fif value after validate' );
#ok( !$form->field('author')->has_input, 'no input for field');

$form->clear;
$fif = $form->fif;
delete $fif->{submit};
ok( ! ( grep { $_ ne '' } ( values %{ $fif } ) ), 'clear clears fif' );
my $params = {
   title => 'Testing form',
   isbn => '02340234',
   pages => '699',
   publisher => '',
};

$form = BookDB::Form::Book->new(item => $book, schema => $schema, params => $params);

$validated = $form->process( $params );

ok( $validated, 'validated with params' );

is( $form->field('pages')->fif, 699, 'get field fif after validation' );

is( $form->field('isbn')->fif, '02340234', 'get field author after validation' );

$params->{$_} = '' for qw/ comment format year /;
$params->{user_updated} = 0;
is_deeply( $form->fif, $params, 'get form fif after validation' );

{
   package My::Form;
   use HTML::FormHandler::Moose;
   extends 'HTML::FormHandler';

   has_field 'my_compound' => ( type => 'Compound' );
   has_field 'my_compound.one';
   has_field 'my_compound.two';
   has_field 'my_compound.three' => ( type => 'Compound' );
   has_field 'my_compound.three.first';
   has_field 'my_compound.three.second';
}

$form = My::Form->new;
ok( $form, 'get form with compound fields' );
$params = {
   'my_compound.one' => 'What',
   'my_compound.two' => 'Is',
   'my_compound.three.first' => 'Up',
   'my_compound.three.second' => 'With you?'
};
$form->process($params);
ok($form->validated, 'form validated');
is_deeply($form->fif, $params, 'fif is correct');

done_testing;
