package WebGUI::Asset::Wobject::HttpProxy;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2005 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use URI;
use LWP;
use HTTP::Cookies;
use HTTP::Request::Common;
use HTML::Entities;
use WebGUI::HTTP;
use WebGUI::International;
use WebGUI::Privilege;
use WebGUI::Session;
use WebGUI::Storage;
use WebGUI::Asset::Wobject;
use WebGUI::Asset::Wobject::HttpProxy::Parse;
use WebGUI::Cache;

our @ISA = qw(WebGUI::Asset::Wobject);


#-------------------------------------------------------------------
sub definition {
	my $class = shift;
	my $definition = shift;
	push(@{$definition}, {
		tableName=>'HttpProxy',
		className=>'WebGUI::Asset::Wobject::HttpProxy',
		properties=>{
			templateId =>{
				fieldType=>"template",
				defaultValue=>'PBtmpl0000000000000033'
				},
			proxiedUrl=>{
				fieldType=>"url",
				defaultValue=>'http://'
				}, 
			timeout=>{
				fieldType=>"selectList",
				defaultValue=>30
				}, 
			removeStyle=>{
				fieldType=>"yesNo",
				defaultValue=>1
				}, 
			filterHtml=>{
				fieldType=>"filterContent",
				defaultValue=>"javascript"
				}, 
			followExternal=>{
				fieldType=>"yesNo",
				defaultValue=>1
				}, 
                        rewriteUrls=>{
				fieldType=>"yesNo",
                                defaultValue=>1
                                },
			followRedirect=>{
				fieldType=>"yesNo",
				defaultValue=>0
				},
			searchFor=>{
				fieldType=>"text",
                                defaultValue=>undef
                                },
                        stopAt=>{
				fieldType=>"text",
                                defaultValue=>undef
                                },
			}
		});
        return $class->SUPER::definition($definition);
}

#-------------------------------------------------------------------
sub getCookieJar {
	my $self = shift;
	my $storage;
	unless ($self->get("cookieJarStorageId")) {
		$storage = WebGUI::Storage->create;
		$self->update({cookieJarStorageId=>$storage->getId});
	} else {
		$storage = WebGUI::Storage->get($self->get("cookieJarStorageId"));
	}
	return $storage;
}

#-------------------------------------------------------------------
sub getEditForm {
	my $self = shift;
	my $tabform = $self->SUPER::getEditForm();
   	$tabform->getTab("display")->template(
      		-value=>$self->getValue('templateId'),
      		-namespace=>"HttpProxy"
   		);
	my %hash;
	tie %hash, 'Tie::IxHash';
	%hash=(5=>5,10=>10,20=>20,30=>30,60=>60);
        $tabform->getTab("properties")->url(
		-name=>"proxiedUrl", 
		-label=>WebGUI::International::get(1,"HttpProxy"),
		-value=>$self->getValue("proxiedUrl")
		);
        $tabform->getTab("security")->yesNo(
        	-name=>"followExternal",
                -label=>WebGUI::International::get(5,"HttpProxy"),
                -value=>$self->getValue("followExternal")
                );
        $tabform->getTab("security")->yesNo(
                -name=>"followRedirect",
                -label=>WebGUI::International::get(8,"HttpProxy"),
                -value=>$self->getValue("followRedirect")
                );
        $tabform->getTab("properties")->yesNo(
                -name=>"rewriteUrls",
                -label=>WebGUI::International::get(12,"HttpProxy"),
                -value=>$self->getValue("rewriteUrls")
                );
        $tabform->getTab("display")->yesNo(
                -name=>"removeStyle",
                -label=>WebGUI::International::get(6,"HttpProxy"),
                -value=>$self->getValue("removeStyle")
                );
	$tabform->getTab("display")->filterContent(
		-name=>"filterHtml",
		-value=>$self->getValue("filterHtml")
		);
        $tabform->getTab("properties")->selectList(
		-name=>"timeout", 
		-options=>\%hash, 
		-label=>WebGUI::International::get(4,"HttpProxy"),
		-value=>[$self->getValue("timeout")]
		);
        $tabform->getTab("display")->text(
                -name=>"searchFor",
                -label=>WebGUI::International::get(13,"HttpProxy"),
                -value=>$self->getValue("searchFor")
                );
        $tabform->getTab("display")->text(
                -name=>"stopAt",
                -label=>WebGUI::International::get(14,"HttpProxy"),
                -value=>$self->getValue("stopAt")
                );
	return $tabform;
}


#-------------------------------------------------------------------
sub getIcon {
	my $self = shift;
	my $small = shift;
	return $session{config}{extrasURL}.'/assets/small/httpProxy.gif' if ($small);
	return $session{config}{extrasURL}.'/assets/httpProxy.gif';
}

#-------------------------------------------------------------------
sub getName {
        return WebGUI::International::get(3,"HttpProxy");
}

#-------------------------------------------------------------------
sub getUiLevel {
	return 5;
}


#-------------------------------------------------------------------
sub purge {
	my $self = shift;
	$self->getCookieJar->delete;	
	$self->SUPER::purge;
}


#-------------------------------------------------------------------
sub view {
	my $self = shift;
	my $cookiebox = WebGUI::URL::escape($session{var}{sessionId});
   	$cookiebox =~ s/[^A-Za-z0-9\-\.\_]//g;  #removes all funky characters
   	$cookiebox .= '.cookie';
   	my $jar = HTTP::Cookies->new(File => $self->getCookieJar->getPath($cookiebox), AutoSave => 1, Ignore_Discard => 1);
   my (%var, %formdata, @formUpload, $redirect, $response, $header, $userAgent, $proxiedUrl, $request, $ttl);

   if($session{form}{func}!~/editSave/i) {
      $proxiedUrl = $session{form}{FormAction} || $session{form}{proxiedUrl} || $self->get("proxiedUrl") ;
   } else {
      $proxiedUrl = $self->get("proxiedUrl");
      $session{env}{REQUEST_METHOD}='GET';
   }

   $redirect=0; 

   return $self->processTemplate({},$self->get("templateId")) unless ($proxiedUrl ne "");
   
   my $cachedContent = WebGUI::Cache->new($proxiedUrl,"URL");
   my $cachedHeader = WebGUI::Cache->new($proxiedUrl,"HEADER");
   $var{header} = $cachedHeader->get;
   $var{content} = $cachedContent->get;
   unless ($var{content} && $session{env}{REQUEST_METHOD}=~/GET/i) {
      $redirect=0; 
      until($redirect == 5) { # We follow max 5 redirects to prevent bouncing/flapping
      $userAgent = new LWP::UserAgent;
      $userAgent->agent($session{env}{HTTP_USER_AGENT});
      $userAgent->timeout($self->get("timeout"));
      $userAgent->env_proxy;

      $proxiedUrl = URI->new($proxiedUrl);

      #my $allowed_url = URI->new($self->get('proxiedUrl'))->abs;;

      #if ($self->get("followExternal")==0 && $proxiedUrl !~ /\Q$allowed_url/i) {
      if ($self->get("followExternal")==0 && 
          (URI->new($self->get('proxiedUrl'))->host) ne (URI->new($proxiedUrl)->host) ) {
	$var{header} = "text/html";
         return "<h1>You are not allowed to leave ".$self->get("proxiedUrl")."</h1>";
      }

      $header = new HTTP::Headers;
	$header->referer($self->get("proxiedUrl")); # To get around referrer blocking

      if($session{env}{REQUEST_METHOD}=~/GET/i || $redirect != 0) {  # request_method is also GET after a redirection. Just to make sure we're
                               						# not posting the same data over and over again.
         if($redirect == 0) {
            foreach my $input_name (keys %{$session{form}}) {
               next if ($input_name !~ /^HttpProxy_/); # Skip non proxied form var's
               $input_name =~ s/^HttpProxy_//;
               $proxiedUrl=WebGUI::URL::append($proxiedUrl,"$input_name=$session{form}{'HttpProxy_'.$input_name}");
            }
         }
         $request = HTTP::Request->new(GET => $proxiedUrl, $header) || return "wrong url"; # Create GET request
      } else { # It's a POST

         my $contentType = 'application/x-www-form-urlencoded'; # default Content Type header

         # Create a %formdata hash to pass key/value pairs to the POST request
         foreach my $input_name (keys %{$session{form}}) {
   	 next if ($input_name !~ /^HttpProxy_/); # Skip non proxied form var's
   	 $input_name =~ s/^HttpProxy_//;
   
            my $uploadFile = $session{cgi}->tmpFileName($session{form}{'HttpProxy_'.$input_name});
            if(-r $uploadFile) { # Found uploaded file
      	       @formUpload=($uploadFile, qq/$session{form}{'HttpProxy_'.$input_name}/);
   	       $formdata{$input_name}=\@formUpload;
	       $contentType = 'form-data'; # Different Content Type header for file upload
   	    } else {
   	      $formdata{$input_name}=qq/$session{form}{'HttpProxy_'.$input_name}/;
            }
         }
         # Create POST request
         $request = HTTP::Request::Common::POST($proxiedUrl, \%formdata, Content_Type => $contentType);
      }
      $jar->add_cookie_header($request);
  
       
      $response = $userAgent->simple_request($request);
   
      $jar->extract_cookies($response);
   
      if ($response->is_redirect) { # redirected by http header
         $proxiedUrl = URI::URL::url($response->header("Location"))->abs($proxiedUrl);;
         $redirect++;
      } elsif ($response->content_type eq "text/html" && $response->content =~ 
                     /<meta[^>]+refresh[^>]+content[^>]*url=([^\s'"<>]+)/gis) {
         # redirection through meta refresh
         my $refreshUrl = $1;
         if($refreshUrl=~ /^http/gis) { #Refresh value is absolute
   	 $proxiedUrl=$refreshUrl;
         } else { # Refresh value is relative
   	 $proxiedUrl =~ s/[^\/\\]*$//; #chop off everything after / in $proxiedURl
            $proxiedUrl .= URI::URL::url($refreshUrl)->rel($proxiedUrl); # add relative path
         }
         $redirect++;
      } else { 
         $redirect = 5; #No redirection found. Leave loop.
      }
      $redirect=5 if (not $self->get("followRedirect")); # No redirection. Overruled by setting
   }
   
   if($response->is_success) {
      $var{content} = $response->content;
      $var{header} = $response->content_type; 
      if($response->content_type eq "text/html" || 
        ($response->content_type eq "" && $var{content}=~/<html/gis)) {
 
        $var{"search.for"} = $self->getValue("searchFor");
        $var{"stop.at"} = $self->getValue("stopAt");
	if ($var{"search.for"}) {
		$var{content} =~ /^(.*?)\Q$var{"search.for"}\E(.*)$/gis;
		$var{"content.leading"} = $1 || $var{content};
		$var{content} = $2;
	}
	if ($var{"stop.at"}) {
		$var{content} =~ /(.*?)\Q$var{"stop.at"}\E(.*)$/gis;
		$var{content} = $1 || $var{content};
		$var{"content.trailing"} = $2;
	}
         my $p = WebGUI::Asset::Wobject::HttpProxy::Parse->new($proxiedUrl, $var{content}, $self->getId,$self->get("rewriteUrls"));
         $var{content} = $p->filter; # Rewrite content. (let forms/links return to us).
         $p->DESTROY; 
   
         if ($var{content} =~ /<frame/gis) {
		$var{header} = "text/html";
            $var{content} = "<h1>HttpProxy: Can't display frames</h1>
                        Try fetching it directly <a href='$proxiedUrl'>here.</a>";
         } else {
            $var{content} =~ s/\<style.*?\/style\>//isg if ($self->get("removeStyle"));
            $var{content} = WebGUI::HTML::cleanSegment($var{content});
            $var{content} = WebGUI::HTML::filter($var{content}, $self->get("filterHtml"));
         }
      }
   } else { # Fetching page failed...
	$var{header} = "text/html";
      $var{content} = "<b>Getting <a href='$proxiedUrl'>$proxiedUrl</a> failed</b>".
   	      "<p><i>GET status line: ".$response->status_line."</i>";
   }
   if ($session{user}{userId} eq '1') {
      $ttl = $session{page}{cacheTimeoutVisitor};
      } else {
          $ttl = $session{page}{cacheTimeout};
      }

   $cachedContent->set($var{content},$ttl);
   $cachedHeader->set($var{header},$ttl);
   }

   if($var{header} ne "text/html") {
	WebGUI::HTTP::setMimeType($var{header});
	return $var{content};
   } else {
   	return $self->processTemplate(\%var,$self->get("templateId")); 
   }
}


#-------------------------------------------------------------------
sub www_edit {
        my $self = shift;
	return $self->getAdminConsole->render(WebGUI::Privilege::insufficient()) unless $self->canEdit;
	$self->getAdminConsole->setHelp("http proxy add/edit");
        return $self->getAdminConsole->render($self->getEditForm->print,WebGUI::International::get("2","HttpProxy"));
}


1;
