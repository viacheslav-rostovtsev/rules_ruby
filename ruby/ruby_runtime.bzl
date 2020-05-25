"""
Creating the ruby runtime workspace
"""

load(
    "//ruby:internal/build_bazel_template.bzl",
    build_bazel_template = "build_bazel_template",
)

load(
    "//ruby:internal/copy_ruby_runtime_template.bzl",
    copy_ruby_runtime_template = "copy_ruby_runtime_template",
)

def create_copy_ruby_runtime_bzl():
  return copy_ruby_runtime_template


def create_build_bazel(srcs_dir):
  # dynamically generate a build file for the new workspace
  return build_bazel_template.format(srcs_dir = srcs_dir)

##
# Implementation for a ruby_runtime rule
# 
def _ruby_runtime_impl(ctx):
  # a folder to extract the sources into
  srcs_dir = "srcs"

  # First try using the prebuilt version
  os_name = ctx.os.name
  working_prebuild_located = False
  for prebuilt_ruby in ctx.attr.prebuilt_rubys:
      if prebuilt_ruby.name.find(os_name) < 0:
          continue
      tmp = "ruby_tmp"
      _execute_and_check_result(ctx, ["mkdir", tmp], quiet = False)
      ctx.extract(archive = prebuilt_ruby, stripPrefix = ctx.attr.strip_prefix, output = tmp)
      res = ctx.execute(["bin/ruby", "--version"], working_directory = tmp)
      _execute_and_check_result(ctx, ["rm", "-rf", tmp], quiet = False)
      if res.return_code == 0:
          ctx.extract(archive = prebuilt_ruby, stripPrefix = ctx.attr.strip_prefix)
          working_prebuild_located = True
  
  if not working_prebuild_located:
    # if there aren't any suitable or working prebuilts download the sources and build one
    ctx.download_and_extract(
      url = ctx.attr.urls,
      stripPrefix = ctx.attr.strip_prefix,
      output = srcs_dir,
    )
  
    # configuring no gem support, no docs and installing inside our workspace
    root_path = ctx.path(".")
    _execute_and_check_result(ctx, ["./configure", "--disable-rubygems", "--disable-install-doc", "--prefix=%s" % root_path.realpath, "--with-ruby-version=ruby_bazel_libroot"], working_directory = srcs_dir, quiet = False)
    
    # nothing special about make and make install
    _execute_and_check_result(ctx, ["make"], working_directory = srcs_dir, quiet = False)
    _execute_and_check_result(ctx, ["make", "install"], working_directory = srcs_dir, quiet = False)

  copy_ruby_runtime_bzl = create_copy_ruby_runtime_bzl()
  ctx.file("copy_ruby_runtime.bzl", copy_ruby_runtime_bzl)

  build_bazel = create_build_bazel(srcs_dir)
  ctx.file("BUILD.bazel", build_bazel)

##
# Creates a workspace with ruby runtime, including
# a ruby executable and ruby standard libraries
#
# urls: url of the ruby sources archive 
# strip_prefix: the path prefix to strip after extracting
# prebuilt_rubys: list of archives with prebuilt ruby versions (for different platforms)
#
ruby_runtime = repository_rule(
  implementation = _ruby_runtime_impl,
  attrs = {
    "urls": attr.string_list(),
    "strip_prefix": attr.string(),
    "prebuilt_rubys": attr.label_list(allow_files = True, mandatory = False),
  }
)

##
# Runs a command and either fails or returns an ExecutionResult
#
def _execute_and_check_result(ctx, command, **kwargs):
  res = ctx.execute(command, **kwargs)
  if res.return_code != 0:
    fail("""Failed to execute command: `{command}`{newline}Exit Code: {code}{newline}STDERR: {stderr}{newline}""".format(
      command = command,
      code = res.return_code,
      stderr = res.stderr,
      newline = "\n"
    ))
  return res
