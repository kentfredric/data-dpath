use MooseX::Declare;

use 5.010;

class Data::DPath::Path {

        use Data::Dumper;
        use Data::DPath::Step;
        use Data::DPath::Point;
        use Text::Balanced qw (
                                      extract_delimited
                                      extract_bracketed
                             );

        has path   => ( isa => "Str",      is  => "rw" );
        has _steps => ( isa => "ArrayRef", is  => "rw", auto_deref => 1, lazy_build => 1 );

#        use overload '~~' => sub { return ( qw/affe tiger fink star/ ) };

#         method op_match($data) {
#                 say "op_match, wantarray = ", Dumper( { wantarray => wantarray });
#                 #say Dumper({ self => $self, data => $data });
#                 return ( qw/affe tiger fink star/ );
#         }

        sub unescape {
                my ($str) = @_;

                return unless defined $str;
                $str =~ s/(?<!\\)\\"/"/g;
                $str =~ s/\\{2}/\\/g;
                return $str;
        }

        sub unquote {
                my ($str) = @_;
                $str =~ s/^"(.*)"$/$1/g;
                return $str;
        }

        sub quoted { shift =~ m,^/",; }                                             # "

        # essentially the Path parser
        method _build__steps {
                my $remaining_path = $self->path;
                my $extracted;
                my @steps;

                push @steps, new Data::DPath::Step( part => '', kind => 'ROOT' );
#                 my ($start) = $remaining_path =~ m,^(//?),;
#                 given ($start) {
#                         when ('//') { push @steps, new Data::DPath::Step( part => $start, kind => 'ANYWHERE'  ) }
#                         when ('/')  { push @steps, new Data::DPath::Step( part => $start, kind => 'ROOT'      ) }
#                 }
                while ($remaining_path) {
                        my $plain_part;
                        my $filter;
                        my $kind;
                        given ($remaining_path)
                        {
                                when ( \&quoted ) {
                                        ($plain_part, $remaining_path) = extract_delimited($remaining_path,'"', "/");
                                        ($filter,     $remaining_path) = extract_bracketed($remaining_path);
                                        $plain_part                    = unescape unquote $plain_part;
                                }
                                default {
                                        ($extracted, $remaining_path) = extract_delimited($remaining_path,'/');

                                        if (not $extracted) {
                                                ($extracted, $remaining_path) = ($remaining_path, undef); # END OF PATH
                                        } else {
                                                $remaining_path = (chop $extracted) . $remaining_path;
                                        }

                                        ($plain_part, $filter) = $extracted =~ m,^/              # leading /
                                                                                 (.*?)           # path part
                                                                                 (\[.*\])?$      # optional filter
                                                                                ,xg;
                                        $plain_part = unescape $plain_part;
                                }
                        }

                        given ($plain_part) {
                                when ('*')  { $kind = 'ANYSTEP'  }
                                when ('..') { $kind = 'PARENT'   }
                                when ('')   { $kind = 'ANYWHERE' }
                                default     { $kind = 'KEY'      }
                        }
                        push @steps, new Data::DPath::Step( part   => $plain_part,
                                                            kind   => $kind,
                                                            filter => $filter );
                }
                pop @steps if $steps[-1]->kind eq 'ANYWHERE'; # ignore final '/'
                $self->_steps( \@steps );
        }

#         # essentially the Path parser
#         method x_build__steps {

#                 my @steps;

#                 my $path = $self->path;
#                 my ($start) = $path =~ m,^(//?),;
#                 $path =~ s,^(//?),,;

#                 given ($start) {
#                         when ('//') { push @steps, new Data::DPath::Step( part => $start, kind => 'ANYWHERE'  ) }
#                         when ('/')  { push @steps, new Data::DPath::Step( part => $start, kind => 'ROOT'      ) }
#                 }
#                 $Data::DPath::DEBUG && say "       lazy ... (start:          $start)";
#                 $Data::DPath::DEBUG && say "       lazy ... (remaining path: $path)";

#                 my @parts = split qr[/], $path;
#                 foreach (@parts) {
#                         my ($part, $filter) =
#                             m/
#                                      ([^\[]*)      # part
#                                      (\[.*\])?     # part filter
#                              /x;
#                         my $kind;
#                         given ($part) {
#                                 when ('*')  { $kind = 'ANYSTEP'    }
#                                 when ('..') { $kind = 'PARENT' }
#                                 default     { $kind = 'KEY'    }
#                         }
#                         push @steps, new Data::DPath::Step( part   => $part,
#                                                             kind   => $kind,
#                                                             filter => $filter );
#                 }
#                 $self->_steps( \@steps );
#         }

        method match($data) {
                my $context = new Data::DPath::Context ( current_points => [ new Data::DPath::Point ( ref => \$data )] );
                return $context->match($self);
        }
}

1;

__END__

=head1 NAME

Data::DPath::Path - Abstraction for a DPath.

Take a string description, parse it, provide frontend methods.

=head2 match( $data )

Returns an array of all values in C<$data> that match the Path object.

=head1 AUTHOR

Steffen Schwigon, C<< <schwigon at cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Steffen Schwigon.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
