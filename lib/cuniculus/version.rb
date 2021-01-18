# frozen-string-literal: true

module Cuniculus
  # The major version of Cuniculus.  Only bumped for major changes.
  MAJOR = 0

  # The minor version of Cuniculus. Bumped for every non-patch level
  # release.
  MINOR = 0

  # The tiny version of Cuniculus.  Usually 0, only bumped for bugfix
  # releases that fix regressions from previous versions.
  TINY  = 1

  # The version of Cuniculus you are using, as a string (e.g. "2.11.0")
  VERSION = [MAJOR, MINOR, TINY].join(".").freeze

  # The version of Cuniculus you are using, as a number (2.11.0 -> 20110)
  VERSION_NUMBER = MAJOR * 10_000 + MINOR * 10 + TINY

  # The version of Cuniculus you are using, as a string (e.g. "2.11.0")
  def self.version
    VERSION
  end
end
