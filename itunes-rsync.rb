#!/usr/bin/ruby
# $Id: itunes-rsync.rb,v 1.5 2009/01/27 09:11:14 jcs Exp $
#
# rsync the files of an itunes playlist with another directory, most likely a
# usb music device.  requires the rubyosa gem ("sudo gem install rubyosa")
#
# Copyright (c) 2009 joshua stein <jcs@jcs.org>
# Copyright (c) 2010 Tom Hayward <tom@tomh.us> added m3u and multiple playlists features
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

require "rubygems"
require "rbosa"

if !ARGV[1]
  puts "usage: #{$0} <itunes playlists ..> <destination directory>"
  exit
end

if Dir[ARGV[-1]].any?
  destdir = ARGV.pop

  if !destdir.match(/\/$/)
    destdir += "/"
  end
else
  puts "error: directory \"#{destdir}\" does not exist, exiting"
  exit
end

# setup work dir
td = `mktemp -d /tmp/itunes-rsync.XXXXX`.strip

# query itunes and create symlinks for each playlist
ARGV.each do |playlist|

  print "querying itunes for playlist \"#{playlist}\"... "

  # disable a stupid xml deprecation warning
  $VERBOSE = nil
  itunes = OSA.app("iTunes")

  itpl = itunes.sources.select{|s| s.name == "Library" }.first.
    user_playlists.select{|p| p.name.downcase == playlist.downcase }.first

  if !itpl
    puts "could not locate, exiting"
    exit
  end

  # build an array of track locations, don't forget to remove nils!
  tracks = itpl.file_tracks.map{|t| t.location }.compact

  puts "found #{tracks.length} track#{tracks.length == 1 ? '' : 's'}."

  if tracks.length > 0
    # figure out where all of them are stored by checking for the greatest common
    # directory of every track
    gcd = ""
    (1 .. tracks.map{|t| t.length }.max).each do |s|
      piece = tracks[0][0 .. s - 1]

      ok = true
      tracks.each do |t|
        if t[0 .. s - 1] != piece
          ok = false
        end
      end

      if ok
        gcd = piece
      else
        break
      end
    end

    # open m3u playlist file for writing
    File.open("#{td}/#{playlist}.m3u",'w') do |f|
      f.puts '#EXTM3U'

      # mirror directory structure and create symlinks
      print "linking files under #{td}/... "

      tracks.each do |t|
        shortpath = t[gcd.length .. t.length - 1]
        tmppath = "#{td}/#{shortpath}"
    
        # write relative path to m3u playlist
        f.puts shortpath

        if !Dir[File.dirname(tmppath)].any?
          # i'm too lazy to emulate -p with Dir.mkdir
          system("mkdir", "-p", File.dirname(tmppath))
        end

        # also too lazy to emulate -f force link (needed if multiple playlists contain the same file)
        system("ln", "-sf", t, File.dirname(tmppath))
      end
  
    end
    puts "done."
  end

end

# times don't ever seem to match up, so only check size
puts "rsyncing to #{destdir}... "
system("rsync", "-Lrv", "--size-only", "--delete", "#{td}/", destdir)

print "cleaning up... "
system("rm", "-rf", td)
puts "done."
