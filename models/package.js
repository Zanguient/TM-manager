const Path = require('path');
const Fs = require('fs');
const Spawn = require('child_process').spawn;

NEWSCHEMA('Package').make(function(schema) {

	schema.define('id', 'UID', true);
	schema.define('filename', 'String(200)');
	schema.define('template', 'String(500)');
	schema.define('remove', Boolean);
	schema.define('npm', Boolean);
        schema.define('database', 'String(200)');
        schema.define('module', 'String(200)'); // Url git for module

	schema.addWorkflow('check', function(error, model, options, callback) {

		var app = APPLICATIONS.findItem('id', model.id);
		if (!app) {
			error.push('error-app-404');
			return callback();
		}

		model.applinker = app.linker;
		model.appdirectory = Path.join(CONFIG('directory-www'), model.applinker);
		model.appfilename = Path.join(model.appdirectory, app.id + '.package');
		model.app = app;
                
                app.database = model.database;
                SuperAdmin.save();

		if (!model.template)
                    return callback();
                
                //is a git repository
                if (model.template.endsWith(".git"))
                    return callback(SUCCESS(true));

		U.download(model.template, ['get', 'dnscache'], function(err, response) {

			if (response.statusCode !== 200) {
				error.push('template', response.statusMessage || '@error-template');
				return callback();
			}

			var writer = Fs.createWriteStream(model.appfilename);
			response.pipe(writer);
			response.on('error', (err) => error.push('template', err));
			CLEANUP(writer, () => callback());
		});

	});

	schema.addWorkflow('stop', function(error, model, options, callback) {
		SuperAdmin.kill(model.app.port, function() {
			setTimeout(() => callback(SUCCESS(true)), 1000);
		});
	});

	schema.addWorkflow('restart', function(error, model, options, callback) {

		if (model.app.stopped) {
			model.app.stopped = false;
			SuperAdmin.save(NOOP);
		}

		run(model.npm, model.app, () => callback(SUCCESS(true)));
	});

	schema.addWorkflow('remove', function(error, model, options, callback) {

		if (!model.remove)
			return callback();
                    
                var async = require('async');

                function removeFolder(location, next) {
                    Fs.readdir(location, function (err, files) {
                        async.each(files, function (file, cb) {
                            file = location + '/' + file
                            Fs.stat(file, function (err, stat) {
                                if (err) 
                                    return cb(err);
                        
                                if (stat.isDirectory()) 
                                    removeFolder(file, cb);
                                else 
                                    Fs.unlink(file, cb);
                            });
                        }, function (err) {
                            if (err) return next(err);
                            Fs.rmdir(location, function (err) {
                                return next(err);
                            });
                        });
                    });
                }


		U.ls(model.appdirectory, function(files, directories) {

			// package
			files = files.remove(model.appfilename);

                        

			// Removes Files
			F.unlink(files, function() {
				directories.wait(function(item, next) {
                                        //console.log(item);
                                        //
                                        //
					//Fs.rmdir(item, () => next());
                                        removeFolder(item, () => next());
				}, () => callback());
			});
		});
	});
        
	schema.addWorkflow('unpack', function(error, model, options, callback) {

		var linker = model.app.linker;
		var directory = Path.join(CONFIG('directory-www'), linker);
		var filename = Path.join(directory, model.app.id + '.package');
                
                //console.log(model);
                
                //is a git repository
                if(model.template.endsWith(".git")) {
                    var Git = require("nodegit");
                    
                    if(model.remove)
                        
                    
                    // Clone a given repository into the `./tmp` folder.
                    return Git.Clone(model.template, directory,{
                        fetchOpts : {
                                    callbacks: {
                                        credentials: function(url, userName) {
                                            return Git.Cred.sshKeyNew(
                                                    userName,
                                                    '/root/.ssh/id_rsa.pub',
                                                    '/root/.ssh/id_rsa',
                                                    CONFIG('ssh-passphrase') || "" //Passphrase
                                            );
                                        },
                                        certificateCheck: function() {
                                            return 1;
                                        }
                                    }
                                }
                    })
                    // Look up this known commit.
                    .then(function(repo) {
                        return callback(SUCCESS(true));
                    })
                    .catch(function(err) { 
                        console.log(err); 
                        error.push('template', err || '@error-template');
                        return callback();
                    });
                }
                

		F.restore(filename, directory, function(err) {

			if (err) {
				error.push(err);
				return callback();
			}

			Spawn('chown', ['-R', SuperAdmin.run_as_user.user, directory]);

			F.unlink([filename], F.error());
			callback(SUCCESS(true));
		});
	});
        
        // Install module in install directory
        schema.addWorkflow('module', function(error, model, options, callback) {

		var linker = model.app.linker;
		var directory = Path.join(CONFIG('directory-www'), linker, 'install');
                
                var moduleUrl = model.module.split('/');
                var module = moduleUrl.last().replace('.git','');
                
                Fs.stat(Path.join(directory, module), function(err, data){
                    if(!err) {
                        error.push('template', 'Module already installed');
                        return callback();
                    }
                });
                
                
                //is a git repository
                if(model.module.endsWith(".git")) {
                    var Git = require("nodegit");
                    
                    // Clone a given repository into the `/install` folder.
                    return Git.Clone(model.module, Path.join(directory, module),{
                        fetchOpts : {
                                    callbacks: {
                                        credentials: function(url, userName) {
                                            return Git.Cred.sshKeyNew(
                                                    userName,
                                                    '/root/.ssh/id_rsa.pub',
                                                    '/root/.ssh/id_rsa',
                                                    CONFIG('ssh-passphrase') || "" //Passphrase
                                            );
                                        },
                                        certificateCheck: function() {
                                            return 1;
                                        }
                                    }
                                }
                    })
                    // Look up this known commit.
                    .then(function(repo) {
                        SuperAdmin.gulpinstall(model.app, module ,function(err){
                            if(err) {
                                error.push('template', err);
                                return callback();
                            }
                            
                            callback(SUCCESS(true));
                        });
                        return;
                    })
                    .catch(function(err) { 
                        console.log(err); 
                        error.push('template', err || '@error-template');
                        return callback();
                    });
                }
                
                error.push('template', 'not a git repository');
                return callback();
	});
        
        schema.addWorkflow('config', function(error, model, options, callback) {
                var linker = model.app.linker;
		var filename = Path.join(CONFIG('directory-www'), linker, 'config');
                
                // copy default config file
                if (!Fs.existsSync(filename)) {
                    Fs.createReadStream(filename + '.sample').pipe(Fs.createWriteStream(filename));
                }
                
                // modify config file for database and useradmin
                Fs.readFile(filename, 'utf8', function (err,data) {
                    if (err) {
                        error.push('template', err);
                        console.log(err);
                        return callback();
                    }
                    
                    var lines = data.split('\n');
                    var subtype;
                    var value;
                    var obj = {};
                    var result;

                    for (var i = 0, len = lines.length; i < len; i++) {
                        var str = lines[i];

                        if (!str || str[0] === '#' || (str[0] === '/' || str[1] === '/'))
                            continue;

                        var index = str.indexOf(':');
                            if (index === -1)
                                continue;

                        var name = str.substring(0, index).trim();
                        if (name === 'debug' || name === 'resources')
                            continue;

                        value = str.substring(index + 1).trim();
                        index = name.indexOf('(');

                        if (index !== -1) {
                            subtype = name.substring(index + 1, name.indexOf(')')).trim().toLowerCase();
                            name = name.substring(0, index).trim();
                        } else
                            subtype = '';
        
                            switch (name) {
                                case 'database' :
                                    lines[i] = "database		  : " + model.app.database;
                                    break;
                                case 'manager-superadmin' :
                                    lines[i] = "manager-superadmin	  : " + CONFIG('superadmin');
                                    break;
                                case 'name':
                                    if(model.app.name)
                                        lines[i] = "name            	  : " + model.app.name;
                                    break;
                            
                        }
                    }
    
                    result = lines.join("\n");

                    Fs.writeFile(filename, result, 'utf8', function (err) {
                        if (err) {
                            error.push('template', err);
                            console.log(err);
                            return callback();
                        }
                        callback();
                    });
                });
	});
});

function run(npm, model, callback) {

	if (npm) {
		return SuperAdmin.npminstall(model, function(err) {
			SuperAdmin.makescripts(model, function() {
				SuperAdmin.restart(model.port, () => callback());
			});
		});
	}

	return SuperAdmin.makescripts(model, function() {
		SuperAdmin.restart(model.port, () => callback());
	});
}
