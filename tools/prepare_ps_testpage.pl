#!/usr/bin/perl -w

my $opts_file = $ARGV[0];
my $out_file = $ARGV[1];
my $logo_file = "/local/testpg/SUSE-logo.eps";
my $photo_file = "/local/testpg/chameleon-photo.eps";

open (OPTS, "$opts_file");
open (SOURCE, "/usr/share/YaST2/data/printer/testpg.ps");
open (OUT, ">$out_file");

my %strings = ();
my @options = ();

$strings{"section1-value-text"} = "()";
$strings{"section2-value-text"} = "()";
$strings{"section3-value-text"} = "()";
$strings{"section4-value-text"} = "()";

my $have_logo = 0;
my $have_photo = 0;

my $line = "";

while ($line = <OPTS>)
{

# encoding

    if ($line =~ /^----X-ENCODING: (.*)$/)
    {
	($strings{"defaultfontname"}) = $line =~ /^----X-ENCODING: (.*)$/;
	if ($strings{"defaultfontname"} eq "h02")
	{
	    $strings{"defaultfontname"} = "(latin2)";
	}
	else
	{
	    $strings{"defaultfontname"} = "(latin1)";
	}
    }

# labels

    elsif ($line =~ /^----X-HEAD:/)
    {
	($strings{"/test-page-title-text"}) = $line =~ /^----X-HEAD: (.*)$/;
    }
    elsif ($line =~ /^----X-SECT1-L:/)
    {
	($strings{"section1-headline-text"}) = $line =~ /^----X-SECT1-L: (.*)$/;
    }
    elsif ($line =~ /^----X-SECT2-L:/)
    {
	($strings{"section2-headline-text"}) = $line =~ /^----X-SECT2-L: (.*)$/;
    }
    elsif ($line =~ /^----X-SECT3-L:/)
    {
	($strings{"section3-headline-text"}) = $line =~ /^----X-SECT3-L: (.*)$/;
    }
    elsif ($line =~ /^----X-SECT4-L:/)
    {
	($strings{"section4-headline-text"}) = $line =~ /^----X-SECT4-L: (.*)$/;
    }

# border lines

    elsif ($line =~ /^----X-BORDER-.:/)
    {
	my $index = 0;
	($index) = $line =~ /^----X-BORDER-(.):.*/;
	($strings{"border-line-text-line-$index"})
	    = $line =~ /^----X-BORDER-.: (.*)$/;
    }
    elsif ($line =~ /^----X-BORDER-4-LEFT:/)
    {
	my $index = 0;
	($index) = $line =~ /^----X-BORDER-4-LEFT:/;
	($strings{"border-line-text-line-4-bottom-left"})
	    = $line =~ /^----X-BORDER-4-LEFT: (.*)$/;
    }
    elsif ($line =~ /^----X-BORDER-4-RIGHT:/)
    {
	my $index = 0;
	($index) = $line =~ /^----X-BORDER-4-RIGHT:/;
	($strings{"border-line-text-line-4-right-top"})
	    = $line =~ /^----X-BORDER-4-RIGHT: (.*)$/;
    }


# values

    elsif ($line =~ /^----X-SECT1:/)
    {
	($strings{"section1-value-text"}) = $line =~ /^----X-SECT1: (.*)$/;
    }
    elsif ($line =~ /^----X-SECT2:/)
    {
	($strings{"section2-value-text"}) = $line =~ /^----X-SECT2: (.*)$/;
    }
    elsif ($line =~ /^----X-SECT3:/)
    {
	($strings{"section3-value-text"}) = $line =~ /^----X-SECT3: (.*)$/;
    }
    elsif ($line =~ /^----X-SECT4:/)
    {
	($strings{"section4-value-text"}) = $line =~ /^----X-SECT4: (.*)$/;
    }
}

close (OPTS);

# process the logo

open (LOGO, "$logo_file");
my @logo_bbox = ();
while ($line = <LOGO>)
{
    if ($line =~ /\%\%BoundingBox: [0-9]+ [0-9]+ [0-9]+ [0-9]+/)
    {
	@logo_bbox
	    = $line =~ /\%\%BoundingBox: ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+)/;
    }
}
close (LOGO);

#process the photo

open (PHOTO, "$photo_file");
my @photo_bbox = ();
while ($line = <PHOTO>)
{
    if ($line =~ /\%\%BoundingBox: [0-9]+ [0-9]+ [0-9]+ [0-9]+/)
    {
	@photo_bbox
	    = $line =~ /\%\%BoundingBox: ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+)/;
    }
}
close (PHOTO);

# process the testpage template

while ($line = <SOURCE>)
{
    if ($line =~ /\/section.-headline-text.*def/)
    {
	my $key = "";
	($key) = $line =~ /.*(section.-.*-text).*def.*/;
	print OUT "/$key $strings{$key} def\n";
    }
    elsif ($line =~ /\/section.-value-text.*def/)
    {
	my $key = "";
	($key) = $line =~ /.*(section.-.*-text).*def.*/;
	print OUT "/$key [ $strings{$key} ] def\n";
    }
    elsif ($line =~ /\/defaultfontname.*def/)
    {
	print OUT "/defaultfontname $strings{\"defaultfontname\"} def\n";
    }
    elsif ($line =~ /\/border-line-text-line.*def/)
    {
	my $key = "";
	my $value = "";
	($key) = $line =~ /border-line-text-line-([^ ]*) /;
	$key = "border-line-text-line-$key";
	$value = $strings{$key};
	print OUT "/$key $value def\n";
    }
    elsif ($line =~ /\/logoBBoxLeft .* def/)
    {
	print OUT "/logoBBoxLeft $logo_bbox[0] def\n";
    }
    elsif ($line =~ /\/logoBBoxBottom .* def/)
    {
	print OUT "/logoBBoxBottom $logo_bbox[1] def\n";
    }
    elsif ($line =~ /\/logoBBoxRight .* def/)
    {
	print OUT "/logoBBoxRight $logo_bbox[2] def\n";
    }
    elsif ($line =~ /\/logoBBoxTop .* def/)
    {
	print OUT "/logoBBoxTop $logo_bbox[3] def\n";
    }
    elsif ($line =~ /^logoContent$/)
    {
	open (LOGO, "$logo_file");
	while ($line = <LOGO>)
	{
	    print OUT $line;
	}
	close (LOGO);
    }
    elsif ($line =~ /\/photoBBoxLeft .* def/)
    {
	print OUT "/photoBBoxLeft $photo_bbox[0] def\n";
    }
    elsif ($line =~ /\/photoBBoxBottom .* def/)
    {
	print OUT "/photoBBoxBottom $photo_bbox[1] def\n";
    }
    elsif ($line =~ /\/photoBBoxRight .* def/)
    {
	print OUT "/photoBBoxRight $photo_bbox[2] def\n";
    }
    elsif ($line =~ /\/photoBBoxTop .* def/)
    {
	print OUT "/photoBBoxTop $photo_bbox[3] def\n";
    }
    elsif ($line =~ /^photoContent$/)
    {
	open (PHOTO, "$photo_file");
	while ($line = <PHOTO>)
	{
	    print OUT $line;
	}
	close (PHOTO);
    }

    else
    {
	print OUT $line;
    }

}

close (OUT);
close (SOURCE);

