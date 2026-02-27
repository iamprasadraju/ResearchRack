#!/usr/bin/env ruby
require 'webrick'
require 'json'
require 'uri'
require 'yaml'

PORT = 4567
ROOT_DIR = File.dirname(__FILE__)
PAPERS_DIR = File.join(ROOT_DIR, '_papers')
BOOKS_DIR = File.join(ROOT_DIR, '_books')
PDFS_DIR = File.join(ROOT_DIR, '_pdfs')

Dir.mkdir(PAPERS_DIR) unless Dir.exist?(PAPERS_DIR)
Dir.mkdir(BOOKS_DIR) unless Dir.exist?(BOOKS_DIR)
Dir.mkdir(PDFS_DIR) unless Dir.exist?(PDFS_DIR)

# Custom servlet to handle CORS properly
class CORSServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_OPTIONS(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'GET, POST, DELETE, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type'
    res['Content-Type'] = 'text/plain'
    res.body = ''
  end
end

class AddPaperServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_OPTIONS(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type'
    res['Content-Type'] = 'text/plain'
    res.body = ''
  end
  
  def do_POST(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Content-Type'] = 'application/json'
    
    begin
      data = JSON.parse(req.body)
      
      filename = data['filename'].to_s.strip
      content = data['content'].to_s
      
      if filename.empty? || content.empty?
        raise 'Missing filename or content'
      end
      
      filename = filename.gsub(/[^a-z0-9_.-]/i, '_')
      filename = filename + '.md' unless filename.end_with?('.md')
      
      filepath = File.join(PAPERS_DIR, filename)
      
      if File.exist?(filepath)
        raise "File already exists: #{filename}"
      end
      
      File.write(filepath, content)
      
      res.status = 200
      res.body = {
        success: true,
        filename: filename,
        path: filepath
      }.to_json
      
      puts "[#{Time.now.strftime('%H:%M:%S')}] Added: #{filename}"
      
    rescue JSON::ParserError => e
      res.status = 400
      res.body = { success: false, error: 'Invalid JSON' }.to_json
    rescue => e
      res.status = 500
      res.body = { success: false, error: e.message }.to_json
      puts "[ERROR] #{e.message}"
    end
  end
end

class RebuildServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_OPTIONS(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type'
    res['Content-Type'] = 'text/plain'
    res.body = ''
  end
  
  def do_POST(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Content-Type'] = 'application/json'
    
    begin
      puts "[#{Time.now.strftime('%H:%M:%S')}] Rebuilding Jekyll..."
      output = `cd "#{ROOT_DIR}" && bundle exec jekyll build 2>&1`
      
      if $?.success?
        res.status = 200
        res.body = { success: true, output: output }.to_json
        puts "[#{Time.now.strftime('%H:%M:%S')}] Rebuild complete"
      else
        raise 'Build failed'
      end
    rescue => e
      res.status = 500
      res.body = { success: false, error: e.message }.to_json
      puts "[ERROR] Rebuild failed: #{e.message}"
    end
  end
end

class ListPapersServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_OPTIONS(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type'
    res['Content-Type'] = 'text/plain'
    res.body = ''
  end
  
  def do_GET(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Content-Type'] = 'application/json'
    
    begin
      papers = Dir.glob(File.join(PAPERS_DIR, '*.md')).map do |f|
        {
          filename: File.basename(f),
          modified: File.mtime(f).iso8601
        }
      end
      
      res.status = 200
      res.body = { success: true, papers: papers, count: papers.size }.to_json
    rescue => e
      res.status = 500
      res.body = { success: false, error: e.message }.to_json
    end
  end
end

class DeletePaperServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_OPTIONS(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type'
    res['Content-Type'] = 'text/plain'
    res.body = ''
  end
  
  def do_POST(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Content-Type'] = 'application/json'
    
    begin
      data = JSON.parse(req.body)
      filename = data['filename'].to_s.strip
      
      if filename.empty?
        raise 'Missing filename'
      end
      
      filename = filename.gsub(/[^a-z0-9_.-]/i, '_')
      filename = filename + '.md' unless filename.end_with?('.md')
      
      filepath = File.join(PAPERS_DIR, filename)
      
      unless File.exist?(filepath)
        raise "File not found: #{filename}"
      end
      
      File.delete(filepath)
      
      res.status = 200
      res.body = { success: true, filename: filename }.to_json
      
      puts "[#{Time.now.strftime('%H:%M:%S')}] Deleted: #{filename}"
      
    rescue JSON::ParserError => e
      res.status = 400
      res.body = { success: false, error: 'Invalid JSON' }.to_json
    rescue => e
      res.status = 500
      res.body = { success: false, error: e.message }.to_json
      puts "[ERROR] #{e.message}"
    end
  end
end

class UpdatePaperServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_OPTIONS(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type'
    res['Content-Type'] = 'text/plain'
    res.body = ''
  end
  
  def do_POST(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Content-Type'] = 'application/json'
    
    begin
      data = JSON.parse(req.body)
      filename = data['filename'].to_s.strip
      
      if filename.empty?
        raise 'Missing filename'
      end
      
      filename = filename.gsub(/[^a-z0-9_.-]/i, '_')
      filename = filename + '.md' unless filename.end_with?('.md')
      
      filepath = File.join(PAPERS_DIR, filename)
      
      unless File.exist?(filepath)
        raise "File not found: #{filename}"
      end
      
      content = File.read(filepath)
      
      frontmatter = {}
      if content =~ /\A---\n(.*?)\n---/m
        YAML.safe_load(Regexp.last_match(1), permitted_classes: [Date]).each { |k, v| frontmatter[k] = v }
      end
      
      if data['category']
        frontmatter['category'] = data['category']
      end
      
      if data['tags']
        frontmatter['tags'] = data['tags'].is_a?(Array) ? data['tags'] : data['tags'].split(',').map(&:strip)
      end
      
      new_frontmatter = frontmatter.map { |k, v| 
        if v.is_a?(Array)
          "#{k}: [#{v.map { |e| '"' + e.to_s + '"' }.join(', ')}]"
        else
          "#{k}: #{v}"
        end
      }.join("\n")
      
      new_content = content.sub(/\A---.*?---\n/m, "---\n#{new_frontmatter}\n---\n")
      
      File.write(filepath, new_content)
      
      res.status = 200
      res.body = { success: true, filename: filename }.to_json
      
      puts "[#{Time.now.strftime('%H:%M:%S')}] Updated: #{filename}"
      
    rescue JSON::ParserError => e
      res.status = 400
      res.body = { success: false, error: 'Invalid JSON' }.to_json
    rescue => e
      res.status = 500
      res.body = { success: false, error: e.message }.to_json
      puts "[ERROR] #{e.message}"
    end
  end
end

class AddBookServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_OPTIONS(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type'
    res['Content-Type'] = 'text/plain'
    res.body = ''
  end
  
  def do_POST(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Content-Type'] = 'application/json'
    
    begin
      data = JSON.parse(req.body)
      
      title = data['title'].to_s.strip
      if title.empty?
        raise 'Missing title'
      end
      
      title_slug = title.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
      filename = "#{title_slug}-#{Time.now.to_i}.md"
      filepath = File.join(BOOKS_DIR, filename)
      
      authors = data['author'].to_s.split(',').map(&:strip).reject(&:empty?)
      cover_url = data['coverUrl'].to_s
      category = data['category'].to_s.strip
      pdf_url = data['pdfUrl'].to_s.strip
      
      subjects = data['subjects'] || []
      publishers = data['publishers'].to_s
      publisher = data['publisher'].to_s
      languages = data['languages'].to_s
      pages = data['pages'].to_s
      edition_count = data['editionCount'].to_s
      isbn13 = data['isbn13'].to_s
      
      description = data['description'].to_s
      description = description.gsub(/^["']+|["']+$/, '').gsub('\\"', '"').gsub("\n", ' ').gsub('--+', '-').strip
      description = description[0..2000] if description.length > 2000
      
      content = <<~CONTENT
---
title: "#{title}"
authors: [#{authors.map { |a| '"' + a + '"' }.join(', ')}]
author: "#{data['author']}"
publish_year: "#{data['year']}"
isbn: "#{data['isbn']}"
isbn13: "#{isbn13}"
cover_url: "#{cover_url}"
openlibrary_url: "#{data['olid'] ? 'https://openlibrary.org/works/' + data['olid'] : ''}"
publishers: "#{publishers}"
publisher: "#{publisher}"
subjects: [#{subjects.map { |s| '"' + s + '"' }.join(', ')}]
languages: "#{languages}"
pages: "#{pages}"
edition_count: "#{edition_count}"
description: "#{description}"
pdf_url: "#{pdf_url}"
date_added: #{Time.now.strftime('%Y-%m-%d')}
---

      CONTENT
      
      File.write(filepath, content)
      
      res.status = 200
      res.body = { success: true, filename: filename, path: filepath }.to_json
      
      puts "[#{Time.now.strftime('%H:%M:%S')}] Added book: #{title}"
      
    rescue JSON::ParserError => e
      res.status = 400
      res.body = { success: false, error: 'Invalid JSON' }.to_json
    rescue => e
      res.status = 500
      res.body = { success: false, error: e.message }.to_json
      puts "[ERROR] #{e.message}"
    end
  end
end

class DeleteBookServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_OPTIONS(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type'
    res['Content-Type'] = 'text/plain'
    res.body = ''
  end
  
  def do_POST(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Content-Type'] = 'application/json'
    
    begin
      data = JSON.parse(req.body)
      filename = data['filename'].to_s.strip
      
      if filename.empty?
        raise 'Missing filename'
      end
      
      filepath = File.join(BOOKS_DIR, filename)
      
      unless File.exist?(filepath)
        raise "File not found: #{filename}"
      end
      
      content = File.read(filepath)
      if content =~ /pdf_url:\s*"([^"]+)"/
        pdf_path = $1
        if pdf_path && !pdf_path.empty? && pdf_path.include?('/_pdfs/')
          pdf_filename = pdf_path.split('/').last
          pdf_filepath = File.join(PDFS_DIR, pdf_filename)
          if File.exist?(pdf_filepath)
            File.delete(pdf_filepath)
            puts "[#{Time.now.strftime('%H:%M:%S')}] Deleted PDF: #{pdf_filename}"
          end
        end
      end
      
      File.delete(filepath)
      
      Dir.chdir(ROOT_DIR) do
        system('bundle', 'exec', 'jekyll', 'build', '--quiet')
      end
      
      res.status = 200
      res.body = { success: true, filename: filename }.to_json
      
      puts "[#{Time.now.strftime('%H:%M:%S')}] Deleted book: #{filename}"
      
    rescue JSON::ParserError => e
      res.status = 400
      res.body = { success: false, error: 'Invalid JSON' }.to_json
    rescue => e
      res.status = 500
      res.body = { success: false, error: e.message }.to_json
      puts "[ERROR] #{e.message}"
    end
  end
end

class UploadPdfServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_OPTIONS(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type'
    res['Content-Type'] = 'text/plain'
    res.body = ''
  end
  
  def do_POST(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Content-Type'] = 'application/json'
    
    begin
      upload_dir = File.join(ROOT_DIR, '_pdfs')
      Dir.mkdir(upload_dir) unless Dir.exist?(upload_dir)
      
      body = req.body
      content_type = req['Content-Type']
      
      if content_type =~ /boundary=(.+)/
        boundary = $1
      else
        return res.body = { success: false, error: 'No boundary' }.to_json
      end
      
      filename = nil
      file_data = nil
      
      parts = body.split("--#{boundary}")
      parts.each do |part|
        if part.include?('filename=') && part !~ /filename=""/
          if part =~ /filename="([^"]+)"/
            filename = $1
          end
          
          idx = part.index("\r\n\r\n")
          if idx
            file_data = part[(idx + 4)..-1]
            file_data = file_data.sub(/\r\n--\s*$/, '') if file_data
          end
          
          break if filename && file_data
        end
      end
      
      if !filename || !file_data || file_data.length < 100
        return res.body = { success: false, error: 'Could not parse PDF file' }.to_json
      end
      
      safe_filename = filename.gsub(/[^a-zA-Z0-9._-]/, '_')
      safe_filename = Time.now.to_i.to_s + '_' + safe_filename
      filepath = File.join(upload_dir, safe_filename)
      
      File.binwrite(filepath, file_data)
      
      pdf_url = "/ResearchRack/_pdfs/#{safe_filename}"
      
      res.status = 200
      res.body = { success: true, url: pdf_url, filename: safe_filename }.to_json
      
      puts "[#{Time.now.strftime('%H:%M:%S')}] Uploaded PDF: #{safe_filename}"
    rescue => e
      res.status = 500
      res.body = { success: false, error: e.message }.to_json
      puts "[ERROR] #{e.message}"
    end
  end
end

class UpdateBookServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_OPTIONS(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type'
    res['Content-Type'] = 'text/plain'
    res.body = ''
  end
  
  def do_POST(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    res['Content-Type'] = 'application/json'
    
    begin
      data = JSON.parse(req.body)
      filename = data['filename'].to_s.strip
      
      if filename.empty?
        raise 'Missing filename'
      end
      
      filepath = File.join(BOOKS_DIR, filename)
      
      unless File.exist?(filepath)
        raise "File not found: #{filename}"
      end
      
      content = File.read(filepath)
      
      frontmatter = {}
      if content =~ /\A---\n(.*?)\n---/m
        frontmatter = YAML.safe_load(Regexp.last_match(1), permitted_classes: [Date]) || {}
      end
      
      if data['category']
        frontmatter['category'] = data['category']
      end
      
      if data.key?('pdfUrl')
        frontmatter['pdf_url'] = data['pdfUrl']
      end
      
      new_frontmatter = frontmatter.map { |k, v| 
        if v.is_a?(Array)
          if v.empty?
            "#{k}: []"
          else
            "#{k}: [" + v.map { |e| 
              if e.is_a?(Hash)
                '{' + e.map { |kk, vv| "\"#{kk}\": #{vv.is_a?(String) ? '"' + vv + '"' : vv}" }.join(', ') + '}'
              else
                '"' + e.to_s + '"'
              end
            }.join(', ') + ']'
          end
        else
          "#{k}: #{v.is_a?(String) ? '"' + v + '"' : v}"
        end
      }.join("\n")
      
      new_content = content.sub(/\A---.*?---\n/m, "---\n#{new_frontmatter}\n---\n")
      
      File.write(filepath, new_content)
      
      Dir.chdir(ROOT_DIR) do
        output = `bundle exec jekyll build 2>&1`
        unless $?.success?
          puts "[JEKYL ERROR] #{output}"
        end
      end
      
      res.status = 200
      res.body = { success: true, filename: filename }.to_json
      
      puts "[#{Time.now.strftime('%H:%M:%S')}] Updated book: #{filename}"
      
    rescue JSON::ParserError => e
      res.status = 400
      res.body = { success: false, error: 'Invalid JSON' }.to_json
    rescue => e
      res.status = 500
      res.body = { success: false, error: e.message }.to_json
      puts "[ERROR] #{e.message}"
    end
  end
end

server = WEBrick::HTTPServer.new(
  Port: PORT,
  DocumentRoot: nil,
  AccessLog: [[STDOUT, WEBrick::AccessLog::COMMON_LOG_FORMAT]]
)

class PdfServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    res['Access-Control-Allow-Origin'] = '*'
    
    filename = req.path_info.gsub('/ResearchRack/_pdfs/', '')
    filepath = File.join(PDFS_DIR, filename)
    
    if File.exist?(filepath) && File.file?(filepath)
      res['Content-Type'] = 'application/pdf'
      res['Content-Disposition'] = 'inline'
      res.body = File.read(filepath)
    else
      res.status = 404
      res.body = 'File not found'
    end
  end
end

server.mount('/_pdfs', PdfServlet)
server.mount('/delete-paper', DeletePaperServlet)
server.mount('/update-paper', UpdatePaperServlet)
server.mount('/add-book', AddBookServlet)
server.mount('/upload-pdf', UploadPdfServlet)
server.mount('/update-book', UpdateBookServlet)
server.mount('/delete-book', DeleteBookServlet)
server.mount('/rebuild', RebuildServlet)
server.mount('/list-papers', ListPapersServlet)

trap('INT') do
  puts "\n[#{Time.now.strftime('%H:%M:%S')}] Shutting down..."
  server.shutdown
end

trap('TERM') do
  puts "\n[#{Time.now.strftime('%H:%M:%S')}] Shutting down..."
  server.shutdown
end

puts "=" * 50
puts "WhiteShelf API Server"
puts "=" * 50
puts "URL:      http://localhost:#{PORT}"
puts "Papers:   #{PAPERS_DIR}"
puts "Books:    #{BOOKS_DIR}"
puts ""
puts "Endpoints:"
puts "  POST /add-paper     Add a new paper"
puts "  POST /delete-paper  Delete a paper"
puts "  POST /update-paper  Update paper"
puts "  POST /add-book      Add a book"
puts "  POST /update-book   Update book"
puts "  POST /delete-book   Delete a book"
puts "  POST /rebuild       Rebuild Jekyll site"
puts "  GET  /list-papers   List all papers"
puts ""
puts "Press Ctrl+C to stop"
puts "=" * 50

server.start
