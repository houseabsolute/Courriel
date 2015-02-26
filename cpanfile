requires "Carp" => "0";
requires "DateTime" => "0";
requires "DateTime::Format::Mail" => "0";
requires "DateTime::Format::Natural" => "0";
requires "Devel::PartialDump" => "0";
requires "Email::Abstract::Plugin" => "0";
requires "Email::Address" => "0";
requires "Email::MIME::Encodings" => "0";
requires "Email::MessageID" => "0";
requires "Encode" => "0";
requires "Exporter" => "0";
requires "File::Basename" => "0";
requires "File::LibMagic" => "0";
requires "File::Slurp::Tiny" => "0";
requires "List::AllUtils" => "0";
requires "List::MoreUtils" => "0.28";
requires "MIME::Base64" => "0";
requires "MIME::QuotedPrint" => "0";
requires "Moose" => "0";
requires "Moose::Role" => "0";
requires "MooseX::Params::Validate" => "0.21";
requires "MooseX::Role::Parameterized" => "0";
requires "MooseX::StrictConstructor" => "0";
requires "MooseX::Types" => "0";
requires "MooseX::Types::Combine" => "0";
requires "MooseX::Types::Common::String" => "0";
requires "MooseX::Types::Moose" => "0";
requires "Scalar::Util" => "0";
requires "Sub::Exporter" => "0";
requires "namespace::autoclean" => "0";
requires "parent" => "0";
requires "perl" => "v5.10.0";
requires "strict" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Spec" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Test::Differences" => "0";
  requires "Test::Fatal" => "0";
  requires "Test::More" => "0.96";
  requires "Test::Requires" => "0";
  requires "utf8" => "0";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "Code::TidyAll" => "0.24";
  requires "Perl::Critic" => "1.123";
  requires "Perl::Tidy" => "20140711";
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::CPAN::Changes" => "0.19";
  requires "Test::Code::TidyAll" => "0.24";
  requires "Test::More" => "0.88";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
  requires "Test::Spelling" => "0.12";
  requires "Test::Version" => "1";
};
