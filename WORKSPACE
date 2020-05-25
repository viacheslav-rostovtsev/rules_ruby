workspace(name = "bazel_rules_ruby")

load ("//ruby:ruby_runtime.bzl", "ruby_runtime")

ruby_runtime (
  name = "ruby_runtime",
  urls = ["https://cache.ruby-lang.org/pub/ruby/2.6/ruby-2.6.5.tar.gz"],
  strip_prefix = "ruby-2.6.5",
  #prebuilt_rubys = ["//prepackaged:ruby-2.6.5_linux_x86_64.tar.gz"],
)
