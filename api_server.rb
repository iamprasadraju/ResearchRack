#!/usr/bin/env ruby
require 'webrick'
require 'json'
require 'uri'
require 'yaml'

PORT = 4567
ROOT_DIR = File.dirname(__FILE__)
PAPERS_DIR = File.join(ROOT_DIR, '_papers')
ROADMAPS_DIR = File.join(ROOT_DIR, '_roadmaps')

Dir.mkdir(PAPERS_DIR) unless Dir.exist?(PAPERS_DIR)
Dir.mkdir(ROADMAPS_DIR) unless Dir.exist?(ROADMAPS_DIR)

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

class ListRoadmapsServlet < WEBrick::HTTPServlet::AbstractServlet
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
      roadmaps = Dir.glob(File.join(ROADMAPS_DIR, '*.md')).map do |f|
        content = File.read(f)
        frontmatter = {}
        if content =~ /\A---\n(.*?)\n---/m
          YAML.safe_load(Regexp.last_match(1), permitted_classes: [Date]).each { |k, v| frontmatter[k] = v }
        end
        {
          filename: File.basename(f),
          title: frontmatter['title'] || File.basename(f, '.md'),
          description: frontmatter['description'] || '',
          category: frontmatter['category'] || ''
        }
      end
      
      res.status = 200
      res.body = { success: true, roadmaps: roadmaps, count: roadmaps.size }.to_json
    rescue => e
      res.status = 500
      res.body = { success: false, error: e.message }.to_json
    end
  end
end

class AddRoadmapServlet < WEBrick::HTTPServlet::AbstractServlet
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
      filename = filename.gsub(/[^a-z0-9_.-]/i, '_')
      filename = filename + '.md' unless filename.end_with?('.md')
      
      filepath = File.join(ROADMAPS_DIR, filename)
      
      if File.exist?(filepath)
        raise "File already exists: #{filename}"
      end
      
      content = <<~CONTENT
---
title: "#{data['title'] || 'Untitled'}"
description: "#{data['description'] || ''}"
category: "#{data['category'] || 'general'}"
nodes: []
---
      CONTENT
      
      File.write(filepath, content)
      
      res.status = 200
      res.body = { success: true, filename: filename, path: filepath }.to_json
      
      puts "[#{Time.now.strftime('%H:%M:%S')}] Added roadmap: #{filename}"
      
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

class DeleteRoadmapServlet < WEBrick::HTTPServlet::AbstractServlet
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
      
      filename = filename.gsub(/[^a-z0-9_.-]/i, '_')
      filename = filename + '.md' unless filename.end_with?('.md')
      
      filepath = File.join(ROADMAPS_DIR, filename)
      
      unless File.exist?(filepath)
        raise "File not found: #{filename}"
      end
      
      File.delete(filepath)
      
      res.status = 200
      res.body = { success: true, filename: filename }.to_json
      
      puts "[#{Time.now.strftime('%H:%M:%S')}] Deleted roadmap: #{filename}"
      
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

class AddNodeServlet < WEBrick::HTTPServlet::AbstractServlet
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
      
      filename = filename.gsub(/[^a-z0-9_.-]/i, '_')
      filename = filename + '.md' unless filename.end_with?('.md')
      
      filepath = File.join(ROADMAPS_DIR, filename)
      
      unless File.exist?(filepath)
        raise "File not found: #{filename}"
      end
      
      content = File.read(filepath)
      
      frontmatter = {}
      if content =~ /\A---\n(.*?)\n---/m
        frontmatter = YAML.safe_load(Regexp.last_match(1), permitted_classes: [Date]) || {}
      end
      
      nodes = frontmatter['nodes'] || []
      
      new_node = {
        'id' => data['id'] || "node_#{Time.now.to_i}",
        'label' => data['label'] || 'New Node',
        'parents' => [],
        'resources' => [],
        'notes' => ''
      }
      
      nodes << new_node
      frontmatter['nodes'] = nodes
      
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
      
      res.status = 200
      res.body = { success: true, node: new_node }.to_json
      
      puts "[#{Time.now.strftime('%H:%M:%S')}] Added node to #{filename}"
      
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

class UpdateNodeServlet < WEBrick::HTTPServlet::AbstractServlet
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
      node_id = data['node_id']
      
      filename = filename.gsub(/[^a-z0-9_.-]/i, '_')
      filename = filename + '.md' unless filename.end_with?('.md')
      
      filepath = File.join(ROADMAPS_DIR, filename)
      
      unless File.exist?(filepath)
        raise "File not found: #{filename}"
      end
      
      content = File.read(filepath)
      
      frontmatter = {}
      if content =~ /\A---\n(.*?)\n---/m
        frontmatter = YAML.safe_load(Regexp.last_match(1), permitted_classes: [Date]) || {}
      end
      
      nodes = frontmatter['nodes'] || []
      
      node_index = nodes.find_index { |n| n['id'] == node_id }
      raise "Node not found: #{node_id}" unless node_index
      
      if data['label']
        nodes[node_index]['label'] = data['label']
      end
      if data.key?('parents')
        nodes[node_index]['parents'] = data['parents']
      end
      if data['resources']
        nodes[node_index]['resources'] = data['resources']
      end
      if data['notes']
        nodes[node_index]['notes'] = data['notes']
      end
      
      frontmatter['nodes'] = nodes
      
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
      
      res.status = 200
      res.body = { success: true, node: nodes[node_index] }.to_json
      
      puts "[#{Time.now.strftime('%H:%M:%S')}] Updated node #{node_id} in #{filename}"
      
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

class DeleteNodeServlet < WEBrick::HTTPServlet::AbstractServlet
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
      node_id = data['node_id']
      
      filename = filename.gsub(/[^a-z0-9_.-]/i, '_')
      filename = filename + '.md' unless filename.end_with?('.md')
      
      filepath = File.join(ROADMAPS_DIR, filename)
      
      unless File.exist?(filepath)
        raise "File not found: #{filename}"
      end
      
      content = File.read(filepath)
      
      frontmatter = {}
      if content =~ /\A---\n(.*?)\n---/m
        frontmatter = YAML.safe_load(Regexp.last_match(1), permitted_classes: [Date]) || {}
      end
      
      nodes = frontmatter['nodes'] || []
      nodes = nodes.reject { |n| n['id'] == node_id }
      
      frontmatter['nodes'] = nodes
      
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
      
      res.status = 200
      res.body = { success: true }.to_json
      
      puts "[#{Time.now.strftime('%H:%M:%S')}] Deleted node #{node_id} from #{filename}"
      
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

server.mount('/add-paper', AddPaperServlet)
server.mount('/delete-paper', DeletePaperServlet)
server.mount('/update-paper', UpdatePaperServlet)
server.mount('/add-roadmap', AddRoadmapServlet)
server.mount('/delete-roadmap', DeleteRoadmapServlet)
server.mount('/add-node', AddNodeServlet)
server.mount('/update-node', UpdateNodeServlet)
server.mount('/delete-node', DeleteNodeServlet)
server.mount('/rebuild', RebuildServlet)
server.mount('/list-papers', ListPapersServlet)
server.mount('/list-roadmaps', ListRoadmapsServlet)

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
puts ""
puts "Endpoints:"
puts "  POST /add-paper      Add a new paper"
puts "  POST /delete-paper  Delete a paper"
puts "  POST /update-paper  Update paper"
puts "  POST /add-roadmap   Add a roadmap"
puts "  POST /delete-roadmap Delete a roadmap"
puts "  POST /add-node      Add node to roadmap"
puts "  POST /update-node  Update node in roadmap"
puts "  POST /delete-node  Delete node from roadmap"
puts "  POST /rebuild       Rebuild Jekyll site"
puts "  GET  /list-papers   List all papers"
puts "  GET  /list-roadmaps List all roadmaps"
puts ""
puts "Press Ctrl+C to stop"
puts "=" * 50

server.start
