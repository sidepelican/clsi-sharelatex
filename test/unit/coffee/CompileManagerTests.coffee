SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../app/js/CompileManager'
tk = require("timekeeper")
EventEmitter = require("events").EventEmitter
Path = require "path"

describe "CompileManager", ->
	beforeEach ->
		@CompileManager = SandboxedModule.require modulePath, requires:
			"./LatexRunner": @LatexRunner = {}
			"./ResourceWriter": @ResourceWriter = {}
			"./OutputFileFinder": @OutputFileFinder = {}
			"settings-sharelatex": @Settings = { path: compilesDir: "/compiles/dir" }
			"logger-sharelatex": @logger = { log: sinon.stub() }
			"child_process": @child_process = {}
		@callback = sinon.stub()

	describe "doCompile", ->
		beforeEach ->
			@output_files = [{
				path: "output.log"
				type: "log"
			}, {
				path: "output.pdf"
				type: "pdf"
			}]
			@output = {
				stdout: "stdout",
				stderr: "stderr"
			}
			@request =
				resources: @resources = "mock-resources"
				rootResourcePath: @rootResourcePath = "main.tex"
				project_id: @project_id = "project-id-123"
				compiler: @compiler = "pdflatex"
				timeout: @timeout = 42000
				processes: @processes = 42
				memory:    @memory = 1024
				cpu_shares: @cpu_shares = 2048
			@Settings.compileDir = "compiles"
			@compileDir = "#{@Settings.path.compilesDir}/#{@project_id}"
			@ResourceWriter.syncResourcesToDisk = sinon.stub().callsArg(2)
			@LatexRunner.runLatex = sinon.stub().callsArgWith(2, null, @output)
			@OutputFileFinder.findOutputFiles = sinon.stub().callsArgWith(2, null, @output_files)
			@CompileManager.doCompile @request, @callback

		it "should write the resources to disk", ->
			@ResourceWriter.syncResourcesToDisk
				.calledWith(@project_id, @resources)
				.should.equal true

		it "should run LaTeX with the given limits", ->
			@LatexRunner.runLatex
				.calledWith(@project_id, {
					mainFile:  @rootResourcePath
					compiler:  @compiler
					timeout:   @timeout
					processes: @processes = 42
					memory:    @memory = 1024
					cpu_shares: @cpu_shares = 2048
				})
				.should.equal true

		it "should find the output files", ->
			@OutputFileFinder.findOutputFiles
				.calledWith(@project_id, @resources)
				.should.equal true

		it "should return the output files and output", ->
			@callback.calledWith(null, @output_files, @output).should.equal true

	describe "syncing", ->
		beforeEach ->
			@page = 1
			@h = 42.23
			@v = 87.56
			@width = 100.01
			@height = 234.56
			@line = 5
			@column = 3
			@file_name = "main.tex"
			@child_process.execFile = sinon.stub()
			@Settings.path.synctexBaseDir = (project_id) => "#{@Settings.path.compilesDir}/#{@project_id}"

		describe "syncFromCode", ->
			beforeEach ->
				@child_process.execFile.callsArgWith(3, null, @stdout = "NODE\t#{@page}\t#{@h}\t#{@v}\t#{@width}\t#{@height}\n", "")
				@CompileManager.syncFromCode @project_id, @file_name, @line, @column, @callback

			it "should execute the synctex binary", ->
				bin_path = Path.resolve(__dirname + "/../../../bin/synctex")
				synctex_path = "#{@Settings.path.compilesDir}/#{@project_id}/output.pdf"
				file_path = "#{@Settings.path.compilesDir}/#{@project_id}/#{@file_name}"
				@child_process.execFile
					.calledWith(bin_path, ["code", synctex_path, file_path, @line, @column], timeout: 10000)
					.should.equal true

			it "should call the callback with the parsed output", ->
				@callback
					.calledWith(null, [{
						page: @page
						h: @h
						v: @v
						height: @height
						width: @width
					}])
					.should.equal true

		describe "syncFromPdf", ->
			beforeEach ->
				@child_process.execFile.callsArgWith(3, null, @stdout = "NODE\t#{@Settings.path.compilesDir}/#{@project_id}/#{@file_name}\t#{@line}\t#{@column}\n", "")
				@CompileManager.syncFromPdf @project_id, @page, @h, @v, @callback

			it "should execute the synctex binary", ->
				bin_path = Path.resolve(__dirname + "/../../../bin/synctex")
				synctex_path = "#{@Settings.path.compilesDir}/#{@project_id}/output.pdf"
				@child_process.execFile
					.calledWith(bin_path, ["pdf", synctex_path, @page, @h, @v], timeout: 10000)
					.should.equal true

			it "should call the callback with the parsed output", ->
				@callback
					.calledWith(null, [{
						file: @file_name
						line: @line
						column: @column
					}])
					.should.equal true