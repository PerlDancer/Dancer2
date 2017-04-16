package Dancer2::Serializer::JSONP;
# ABSTRACT: Serializer for handling JSON data with padding (JSONP)

use Moo;

extends 'Dancer2::Serializer::JSON';

#has '+content_type' => ( default => sub {'text/javascript'} );

around serialize => sub {
  my ($orig, $self, $entity, $options) = @_;
  my $json = $orig->($self, $entity, $options);
  if ($self->request and $self->request->_query_params and $self->request->_query_params->{callback}) {
    my $cb = $self->request->_query_params->{callback};
    return "$cb($json);";
  }
  return $json;
};

1;

