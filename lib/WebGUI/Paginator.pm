package WebGUI::Paginator;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2005 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use WebGUI::International;
use WebGUI::Session;
use WebGUI::URL;
use WebGUI::Utility;

=head1 NAME

Package WebGUI::Paginator

=head1 DESCRIPTION

Package that paginates rows of arbitrary data for display on the web.

=head1 SYNOPSIS

 use WebGUI::Paginator;
 $p = WebGUI::Paginator->new("/index.pl/page_name?this=that");
 $p->setDataByArrayRef(\@array);
 $p->setDataByQuery($sql);

 $p->appendTemplateVars($hashRef);
 $html = $p->getBar;
 $html = $p->getBarAdvanced;
 $html = $p->getBarSimple;
 $html = $p->getBarTraditional;
 $html = $p->getFirstPageLink;
 $html = $p->getLastPageLink;
 $html = $p->getNextPageLink;
 $integer = $p->getNumberOfPages;
 $html = $p->getPage;
 $arrayRef = $p->getPageData;
 $integer = $p->getPageNumber;
 $html = $p->getPageLinks;
 $html = $p->getPreviousPageLink;
 $integer = $p->getRowCount;

=head1 METHODS

These methods are available from this class:

=cut


#-------------------------------------------------------------------

=head2 appendTemplateVars ( hashRef )

Adds paginator template vars to a hash reference.

=head3 hashRef

The hash reference to append the variables to.

=cut

sub appendTemplateVars {
	my $self = shift;
	my $var = shift;
	$var->{'pagination.isFirstPage'} = ($self->getPageNumber == 1);
	$var->{'pagination.isLastPage'} = ($self->getPageNumber == $self->getNumberOfPages);
	$var->{'pagination.firstPage'} = $self->getFirstPageLink;
	$var->{'pagination.lastPage'} = $self->getLastPageLink;
	$var->{'pagination.nextPage'} = $self->getNextPageLink;
	$var->{'pagination.previousPage'} = $self->getPreviousPageLink;
	$var->{'pagination.pageNumber'} = $self->getPageNumber;
	$var->{'pagination.pageCount'} = $self->getNumberOfPages;
	$var->{'pagination.pageCount.isMultiple'} = ($self->getNumberOfPages > 1);
	$var->{'pagination.pageList'} = $self->getPageLinks;
	$var->{'pagination.pageList.upTo10'} = $self->getPageLinks(10);
	$var->{'pagination.pageList.upTo20'} = $self->getPageLinks(20);
}


#-------------------------------------------------------------------

=head2 getBar ( )

Returns the pagination bar including First, Previous, Next, and last links. If there's only one page, nothing is returned.

=cut

sub getBar {
        my ($output);
        if ($_[0]->getNumberOfPages > 1) {
                $output = '<div class="pagination">';
                $output .= $_[0]->getFirstPageLink;
                $output .= ' &middot; ';
                $output .= $_[0]->getPreviousPageLink;
                $output .= ' &middot; ';
                $output .= $_[0]->getNextPageLink;
                $output .= ' &middot; ';
                $output .= $_[0]->getLastPageLink;
                $output .= '</div>';
                return $output;
        } else {
                return "";
        }
}


#-------------------------------------------------------------------

=head2 getBarAdvanced ( )

Returns the pagination bar including First, Previous, Page Numbers, Next, and Last links. If there's only one page, nothing is returned.

=cut

sub getBarAdvanced {
        my ($output);
        if ($_[0]->getNumberOfPages > 1) {
                $output = '<div class="pagination">';
                $output .= $_[0]->getFirstPageLink;
                $output .= ' &middot; ';
                $output .= $_[0]->getPreviousPageLink;
                $output .= ' &middot; ';
                $output .= $_[0]->getPageLinks;
                $output .= ' &middot; ';
                $output .= $_[0]->getNextPageLink;
                $output .= ' &middot; ';
                $output .= $_[0]->getLastPageLink;
                $output .= '</div>';
                return $output;
        } else {
                return "";
        }
}


#-------------------------------------------------------------------

=head2 getBarSimple ( )

Returns the pagination bar including only Previous and Next links. If there's only one page, nothing is returned.

=cut 

sub getBarSimple {
	my ($output);
	if ($_[0]->getNumberOfPages > 1) {
		$output = '<div class="pagination">';
		$output .= $_[0]->getPreviousPageLink;
		$output .= ' &middot; ';
		$output .= $_[0]->getNextPageLink;
		$output .= '</div>';
		return $output;
	} else {
		return "";
	}
}


#-------------------------------------------------------------------

=head2 getBarTraditional ( )

Returns the pagination bar including Previous, Page Numbers, and Next links. If there's only one page, nothing is returned.

=cut

sub getBarTraditional {
        my ($output);
        if ($_[0]->getNumberOfPages > 1) {
                $output = '<div class="pagination">';
                $output .= $_[0]->getPreviousPageLink;
                $output .= ' &middot; ';
                $output .= $_[0]->getPageLinks;
                $output .= ' &middot; ';
                $output .= $_[0]->getNextPageLink;
                $output .= '</div>';
                return $output;
        } else {
                return "";
        }
}


#-------------------------------------------------------------------

=head2 getColumnNames ( )

Returns an array containing the column names

=cut

sub getColumnNames {
	if(ref $_[0]->{_columnNames} eq 'ARRAY') {
		return @{$_[0]->{_columnNames}};
	}
}


#-------------------------------------------------------------------

=head2 getFirstPageLink ( )

Returns a link to the first page's data.

=cut

sub getFirstPageLink {
        my ($text, $pn);
	$pn = $_[0]->getPageNumber;
        $text = '|&lt;'.WebGUI::International::get(404);
        if ($pn > 1) {
                return '<a href="'.
			WebGUI::URL::append($_[0]->{_url},($_[0]->{_formVar}.'=1'))
			.'">'.$text.'</a>';
        } else {
                return $text;
        }
}


#-------------------------------------------------------------------

=head2 getLastPageLink (  )

Returns a link to the last page's data.

=cut

sub getLastPageLink {
        my ($text, $pn);
	$pn = $_[0]->getPageNumber;
        $text = WebGUI::International::get(405).'&gt;|';
        if ($pn != $_[0]->getNumberOfPages) {
                return '<a href="'.
			WebGUI::URL::append($_[0]->{_url},($_[0]->{_formVar}.'='.$_[0]->getNumberOfPages))
			.'">'.$text.'</a>';
        } else {
                return $text;
        }
}


#-------------------------------------------------------------------

=head2 getNextPageLink (  )

Returns a link to the next page's data.

=cut

sub getNextPageLink {
        my ($text, $pn);
	$pn = $_[0]->getPageNumber;
        $text = WebGUI::International::get(92).'&raquo;';
        if ($pn < $_[0]->getNumberOfPages) {
                return '<a href="'.WebGUI::URL::append($_[0]->{_url},($_[0]->{_formVar}.'='.($pn+1))).'">'.$text.'</a>';
        } else {
                return $text;
        }
}


#-------------------------------------------------------------------

=head2 getNumberOfPages ( )

Returns the number of pages in this paginator.

=cut

sub getNumberOfPages {
	my $pageCount = int(($#{$_[0]->{_rowRef}}+1)/$_[0]->{_rpp});
	$pageCount++ unless (($#{$_[0]->{_rowRef}}+1)%$_[0]->{_rpp} == 0);
	return $pageCount;
}


#-------------------------------------------------------------------

=head2 getPage ( [ pageNumber ] )

Returns the data from the page specified as a string. 

B<NOTE:> This is really only useful if you passed in an array reference of strings when you created this object.

=head3 pageNumber

Defaults to the page you're currently viewing. This is mostly here as an override and probably has no real use.

=cut

sub getPage {
	return join("",@{$_[0]->getPageData($_[1])});
}


#-------------------------------------------------------------------

=head2 getPageData ( [ pageNumber ] )

Returns the data from the page specified as an array reference.

=head3 pageNumber

Defaults to the page you're currently viewing. This is mostly here as an override and probably has no real use.

=cut

sub getPageData {
	my ($i, @pageRows, $allRows, $pageCount, $pageNumber, $rowsPerPage, $pageStartRow, $pageEndRow);
        $pageNumber = $_[1] || $_[0]->getPageNumber;
        $pageCount = $_[0]->getNumberOfPages;
        return [] if ($pageNumber > $pageCount);
        $rowsPerPage = $_[0]->{_rpp};
        $pageStartRow = ($pageNumber*$rowsPerPage)-$rowsPerPage;
        $pageEndRow = $pageNumber*$rowsPerPage;
	$allRows = $_[0]->{_rowRef};
        for ($i=$pageStartRow; $i<$pageEndRow; $i++) {
		$pageRows[$i-$pageStartRow] = $allRows->[$i] if ($i <= $#{$_[0]->{_rowRef}});
        }
	return \@pageRows;
}

#-------------------------------------------------------------------

=head2 getPageNumber ( )

Returns the current page number. If no page number can be found then it returns 1.

=cut

sub getPageNumber {
        return $_[0]->{_pn};
}

#-------------------------------------------------------------------

=head2 getPageLinks ( [ limit ] )

Returns links to all pages in this paginator.

=head3 limit

An integer representing the maximum number of page links to return. Defaultly all page links will be returned.

=cut

sub getPageLinks {
	my $self = shift;
	my $limit = shift;
	my $pn = $self->getPageNumber;
	my @pages;
	for (my $i=0; $i<$self->getNumberOfPages; $i++) {
		if ($i+1 == $pn) {
			push(@pages,($i+1));
		} else {
			push(@pages,'<a href="'.WebGUI::URL::append($self->{_url},($self->{_formVar}.'='.($i+1))).'">'.($i+1).'</a>');
		}
	}
	if ($limit) {
		my $output;
		my $i = 1;
		my $minPage = $self->getPageNumber - round($limit/2);
		my $maxPage = $minPage + $limit;
		my $start = ($minPage > 0) ? $minPage : 1;
		my $end = ($maxPage < $self->getPageNumber) ? $self->getPageNumber : $maxPage;
		foreach my $page (@pages) {
			if ($i <= $end && $i >= $start) {
				$output .= $page.' ';
			}
			$i++;
		}
		return $output;
	} else {
		return join(" ",@pages);
	}
}


#-------------------------------------------------------------------

=head2 getPreviousPageLink ( )

Returns a link to the previous page's data. 

=cut

sub getPreviousPageLink {
	my ($text, $pn);
	$pn = $_[0]->getPageNumber;
	$text = '&laquo;'.WebGUI::International::get(91);
	if ($pn > 1) {
		return '<a href="'.WebGUI::URL::append($_[0]->{_url},($_[0]->{_formVar}.'='.($pn-1))).'">'.$text.'</a>';
        } else {
        	return $text;
        }
}


#-------------------------------------------------------------------

=head2 getRowCount ( )

Returns a count of the total number of rows in the paginator.

=cut

sub getRowCount {
	return $_[0]->{_totalRows};
}


#-------------------------------------------------------------------

=head2 new ( currentURL [, paginateAfter, pageNumber, formVar ] )

Constructor.

=head3 currentURL

The URL of the current page including attributes. The page number will be appended to this in all links generated by the paginator.

=head3 paginateAfter

The number of rows to display per page. If left blank it defaults to 50.

=head3 pageNumber 

By default the page number will be determined by looking at $session{form}{pn}. If that is empty the page number will be defaulted to "1". If you'd like to override the page number specify it here.

=head3 formVar

Specify the form variable the paginator should use in it's links.  Defaults to "pn".

=cut

sub new {
	my $class = shift;
	my $currentURL = shift;
	my $rowsPerPage = shift || 25;
	my $formVar = shift || "pn";
	my $pn = shift || $session{form}{$formVar} || 1;
        bless {_url => $currentURL, _rpp => $rowsPerPage, _formVar => $formVar, _pn => $pn}, $class;
}

#-------------------------------------------------------------------

=head2 setDataByArrayRef ( arrayRef )

Provide the paginator with data by giving it an array reference.

=head3 arrayRef

The array reference that contains the data to be paginated.

=cut

sub setDataByArrayRef {
	my $self = shift;
	my $rowRef = shift;
	$self->{_rowRef} = $rowRef;
	$self->{_totalRows} = $#{$rowRef};
}


#-------------------------------------------------------------------

=head2 setDataByQuery ( query [, dbh, unconditional, placeholders ] )

Retrieves a data set from a database and replaces whatever data set was passed in through the constructor.

B<NOTE:> This retrieves only the current page's data for efficiency.

=head3 query

An SQL query that will retrieve a data set.

=head3 dbh

A DBI-style database handler. Defaults to the WebGUI site handler.

=head3 unconditional

A boolean indicating that the query should be read unconditionally. Defaults to "0". If set to "1" and the unconditional read results in an error, the error will be returned by this method.

=head3 placeholders

An array reference containing a list of values to be used in the placeholders defined in the SQL statement.

=cut

sub setDataByQuery {
	my ($sth, $rowCount, @row);
	my ($self, $sql, $dbh, $unconditional, $placeholders) = @_;
	$dbh ||= WebGUI::SQL->getSlave;
	if ($unconditional) {
		$sth = WebGUI::SQL->unconditionalRead($sql,$dbh,$placeholders);
		return $sth->errorMessage if ($sth->errorCode > 0);
	} else {
		$sth = WebGUI::SQL->read($sql,$dbh,$placeholders);
	}
	$self->{_totalRows} = $sth->rows;
	$self->{_columnNames} = [ $sth->getColumnNames ];
	my $pageCount = 1;
	while (my $data = $sth->hashRef) {
		$rowCount++;
		if ($rowCount/$self->{_rpp} > $pageCount) {	
			$pageCount++;
		}
		if ($pageCount == $self->getPageNumber) {
			push(@row,$data);	
		} else {
			push(@row,{});
		}
	}
	$sth->finish;
	$self->{_rowRef} = \@row;
	return "";
}

1;


