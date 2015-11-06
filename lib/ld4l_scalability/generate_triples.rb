#! /usr/bin/env ruby

=begin
--------------------------------------------------------------------------------

Generate files of meaningless triples.

The files are created in a directory, replacing any existing .nt files. Together,
the files constitute a set of triples with no duplications.

The triples will be created from permutations of resource URIs, property URIs,
and data values. There are equal numbers of resource URIs and data values. The
count of resource and the count of properties must each be odd, and must be relatively prime.

The routine will generate triples up to the number requested, which must be less
than (or equal to) nResources * nProperties * 2. It will divide the generated triples
into the number of requested, files, dividing as evenly as possible.

To simulate representative use, the number of properties should be much less than
the number of resources.

--------------------------------------------------------------------------------

Usage: ld4l_generate_triples <dir> <num_triples> <num_files> <num_subjects> <num_predicates> <num_objects> [OVERWRITE]

--------------------------------------------------------------------------------
=end

module Ld4lScalability
  class GenerateTriples
    USAGE_TEXT = 'Usage is ld4l_generate_triples <dir> <num_triples> <num_files> <num_subjects> <num_predicates> <num_objects> [OVERWRITE]'
    def process_arguments(args)
      overwrite_directory = args.delete('OVERWRITE')

      raise UserInputError.new(USAGE_TEXT) unless args && 6 == args.size

      @dir_path = File.expand_path(args[0])
      raise UserInputError.new("Can't create #{@dir_path}: no parent directory.") unless Dir.exist?(File.dirname(@dir_path))
      if File.exist?(@dir_path)
        if (overwrite_directory)
          delete_directory_contents(@dir_path)
        else
          raise UserInputError.new("#{@dir_path} already exists -- specify OVERWRITE")
        end
      else
        Dir.mkdir(@dir_path)
      end

      @number_of_triples = args[1].to_i
      @number_of_files = args[2].to_i
      @number_of_subjects = args[3].to_i
      @number_of_predicates = args[4].to_i
      @number_of_objects = args[5].to_i
      raise UserInputError.new("Number of triples must be positive.") unless @number_of_triples > 0
      raise UserInputError.new("Number of files must be positive.") unless @number_of_files > 0
      raise UserInputError.new("Number of subjects must be positive.") unless @number_of_subjects > 0
      raise UserInputError.new("Number of predicates must be positive.") unless @number_of_predicates > 0
      raise UserInputError.new("Number of objects must be positive.") unless @number_of_objects > 0

      raise UserInputError.new("Number of files must not be more than the number of triples.") if @number_of_files > @number_of_triples
      raise UserInputError.new("Number of triples must not be larger than the number of combinations.") if @number_of_triples > @number_of_subjects * @number_of_predicates * @number_of_objects

      raise UserInputError.new("Numbers of subject, predicates and objects must be relatively prime.") unless @number_of_subjects.gcd(@number_of_objects) == 1 && @number_of_subjects.gcd(@number_of_predicates) == 1 && @number_of_predicates.gcd(@number_of_objects) == 1

      @file_index = 0

      puts "dir = #{File.expand_path(@dir_path)}"
      puts "triples = #{@number_of_triples}, files = #{@number_of_files}, subjects = #{@number_of_subjects}, predicates = #{@number_of_predicates}, objects = #{@number_of_objects}"

      write_manifest(args)
    end

    def delete_directory_contents(dir)
      Dir.chdir(dir) do
        Dir.entries(".").each do |fname|
          File.delete(fname) unless fname.start_with?(".")
        end
      end
    end

    def write_manifest(args)
      File.open(File.expand_path('__MANIFEST.txt', @dir_path), 'w') do |f|
        f.puts Time.now
        f.puts args.join(' ')
      end
    end

    def generate()
      @number_of_triples.times do |i|
        write_triple(create_triple(i))
      end
      close_file if file_is_open?
    end

    def create_triple(i)
      "#{create_subject(i)} #{create_predicate(i)} #{create_object(i)} ."
    end

    def create_subject(i)
      index = 1 + i % @number_of_subjects
      "<http://my.graph#r#{index}>"
    end

    def create_predicate(i)
      index = 1 + i % @number_of_predicates
      "<http://my.graph#p#{index}>"
    end

    def create_object(i)
      index = 1 + i % @number_of_objects
      case index % 3
      when 1
        "<http://my.graph#r#{index}>"
      when 2
        %{"#{index}"^^<http://www.w3.org/2001/XMLSchema#integer>}
      else
        %{"string#{index}"}
      end
    end

    def write_triple(triple)
      open_next_file unless file_is_open?
      write_to_file(triple)
      close_file if file_is_full?
    end

    def open_next_file()
      @file_index +=1
      @file = File.open(File.expand_path(create_filename, @dir_path), "w")
      @line_number = 0
    end

    def create_filename()
      sprintf('triples%03d.nt', @file_index)
    end

    def write_to_file(triple)
      @file.puts(triple)
      @line_number += 1
    end

    def file_is_full?
      @line_number >= lines_in_file
    end

    def lines_in_file
      (@number_of_triples / @number_of_files.to_f).ceil
    end

    def close_file
      @file.close
      @file = nil
    end

    def file_is_open?
      true && @file
    end

    def run
      begin
        process_arguments(ARGV)
        generate
      rescue UserInputError
        puts
        puts "ERROR: #{$!}"
        puts
      end
    end
  end
end