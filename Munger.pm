#!/usr/local/bin/perl -w

package HTML::Munger;

use strict;
use integer;

use HTML::Parser;

use vars qw($VERSION @ISA);

$VERSION = '0.01';
@ISA     = ('HTML::Parser');

# constructor
sub new {
    my $proto = shift || return undef;
    my $class = ref($proto) || $proto;
    my $self  = $class->SUPER::new();

    $self->{'munger'} = undef;

    bless $self, $class;
    return $self;
}


# munging code
sub munge {
    my $self           = shift || return undef;
    $self->{'URL'}     = shift || return undef;
    $self->{'selfURL'} = shift || return undef;
    my $content        = shift || return undef;

    $self->{'munged'} = '';

    # parse the hostname
    $self->{'host'} = $self->{'URL'};
    $self->{'host'} =~ s/^http:\/\///i;
    $self->{'host'} .= "/";
    $self->{'host'} =~ s/\/.*$//;

    # parse the directory
    $self->{'dir'} = $self->{'URL'};
    $self->{'dir'} =~ s/\/[^\/]*$/\//;
    ($self->{'dir'} !~ /^\//) && ($self->{'dir'} = '/' . $self->{'dir'});

    # debugging
    $self->{'munged'} .= '<!-- URL = ' . $self->{'URL'} . ', host = '
                      .  $self->{'host'} . ', dir = ' . $self->{'dir'}
                      .  ' -->';

    $self->parse($content);
    $self->eof();

    return $self->{'munged'};
}


sub set_munger {
    my($self, $coderef) = @_;
    
    $self->{'munger'} = $coderef;

    return(undef);
}


sub declaration {
    my($self, $decl) = @_;

    $self->{'munged'} .= "<!$decl>";

    return(undef);
}


sub start {
    my($self, $tag, $attr, $attrseq, $origtext) = @_;
    my($current);

    $self->{'munged'} .= "<$tag";
    foreach $current (@{$attrseq}) {
        if (defined($attr->{$current})) {
            my($currentval) = $attr->{$current};
            $self->{'munged'} .= " $current=\"";
        
            # a few attributes get munged up
            if ($current =~ /(src|href|codebase|action|background)/i) {
                if ($currentval =~ /:(\/\/)?/) {
                    # this is an absolute URL, so we do nothing
                } elsif ($currentval =~ /^\//) {
                    # this is an absolute pathname URL (begins with /)
                    # so we prepend the hostname
                    $currentval = "http://" . $self->{'host'} . "$currentval";
                } else {
                    # assume this is a relative URL, so we'll add both the
                    # hostname and directory
                    $currentval = "http://" . $self->{'host'} .
                                  $self->{'dir'} . "$currentval";
                }
            }

            # and a couple of others are further munged
            if (($current =~ /^href/i)
               || (($tag =~ /^frame/i) && ($current =~ /^src/i))) {
                $currentval = $self->{'selfURL'} . "$currentval";
            }

            $self->{'munged'} .= "$currentval\"";
        } else {
            $self->{'munged'} .= " $current";
        }
    }
    $self->{'munged'} .= ">";

    return(undef);
}


sub end {
    my($self, $tag, $origtext) = @_;

    $self->{'munged'} .= $origtext;

    return(undef);
}


sub text {
    my($self, $text) = @_;

    if (defined($self->{'munger'})) {
        $self->{'munged'} .= &{$self->{'munger'}}($text);
    } else {
        $self->{'munged'} .= $text;
    }

    return(undef);
}


sub comment {
    my($self, $comment) = @_;

    $self->{'munged'} .= "<!--$comment-->";

    return(undef);
}

1;
__END__

=head1 NAME

HTML::Munger - Module which simplifies the creation of web filters.

=head1 SYNOPSIS

 use HTML::Munger;

 $munger = new HTML::Munger;
 $munger->set_munger(\&filter_function);
 $output = $munger->munge($URL, $selfURL, $input);

=head1 DESCRIPTION

HTML::Munger is a simple module which allows easy creation of web page
filtering software.  It was first written to build the pootifier at
http://pootpoot.com/?pootify

The main task which this module performs is attempting to make all the
relative links on the filtered page absolute, so that images, and hyperlinks
work correctly.  It also makes frames and hyperlinks properly filter back
through the filter.

This leaves two major tasks for the user of HTML::Munger: fetching the original
page, and building a simple munging function.

=head2 API

There are really only three important functions you need to know how to call
in order to use this module:

=over 3

=item B<new>

This is a simple constructor, which takes no arguments aside from the implicit
class.  It returns a blessed reference which is used to call the other methods.

=item B<set_munger>

This method registers the filtering function you want to be called to produce
the filtered text.  The function specified will be called repeatedly with
short blocks of text.  For example, given the following HTML:

 <P>Hello</P><CENTER>The quick brown <I>fox</I></CENTER>

The filtering function would be called three times, with 'Hello',
'The quick brown ', and 'fox', respectively, as input.  The filter function
is expected to return a string which will replace the given input in the
output of the munge() call.

=item B<munge>

This method takes three arguments.  The first is the URL of the page which is
being munged.  Note that the 'munge' method does NOT fetch the page for you!
It needs this information in order to make relative links in the page absolute.
The second argument is the URL of the filtering program.  This is used to
make all hyperlinks and frames pass back through the filter.  Finally, it takes
the input HTML as its third argument.  This method returns the munged HTML
string, which can then be further parsed or sent to the user.

=back

=head1 BUGS

Hopefully none.

=head1 AUTHOR

J. David Lowe, dlowe@pootpoot.com

=head1 SEE ALSO

perl(1), HTML::Parser(3)

=cut
