classdef FileLoadSaveClass < matlab.mixin.Copyable
    
    properties (Access = public)
        location
        errmsgs
        warnmsgs
    end
    
    
    properties (Access = private)
        filename;
        fileformat;
        supportedFomats;
        err;
        warn;
        dataStorageScheme;        
    end
    
    
    methods
        
        % ----------------------------------------------------------------------------------
        function obj = FileLoadSaveClass()
            obj.filename = '';
            obj.fileformat = '';
            obj.supportedFomats = struct( ...
                'matlab', {{'.mat','matlab','mat'}}, ...
                'hdf5', {{'hdf','.hdf','hdf5','.hdf5','hf5','.hf5','h5','.h5'}} ...
                );
            obj.err = 0;
            obj.errmsgs = {};
            obj.warnmsgs = {};
            obj.dataStorageScheme = 'memory';
            obj.location = '';
        end
        
        
        % ---------------------------------------------------------
        function Load(obj, filename, params, format)
            if ~exist('filename','var')
                filename = obj.filename;
            end
            if ~exist('format','var')
                format = obj.fileformat;
            elseif obj.Supported(format)
                obj.fileformat = format;
            end
            if ~exist('params','var')
                params = [];
            end            
                        
            switch(lower(format))
                case obj.supportedFomats.matlab
                    if ismethod(obj, 'LoadMat')
                        obj.err = obj.LoadMat(filename, params);
                    end
                case obj.supportedFomats.hdf5
                    if ismethod(obj, 'LoadHdf5')
                        obj.err = obj.LoadHdf5(filename, params);
                    end
            end
        end
        
        
        % ---------------------------------------------------------
        function Save(obj, filename, params, format)
            if ~exist('filename','var')
                filename = obj.filename;
            end            
            if ~exist('params','var')
                params = [];
            end            
            if ~exist('format','var')
                format = obj.fileformat;
            end
            
            p = fileparts(filename);
            if isempty(p)
                filename = ['./', filename];
            end
                       
            switch(lower(format))
                case obj.supportedFomats.matlab
                    if ismethod(obj, 'SaveMat')
                        obj.SaveMat(filename, params);
                    end
                case obj.supportedFomats.hdf5
                    if ismethod(obj, 'SaveHdf5')
                        obj.SaveHdf5(filename, params);
                    end
            end
        end
        
        
        % ---------------------------------------------------------
        function b = Supported(obj, format)
            b = true;
            switch(lower(format))
                case obj.supportedFomats.matlab
                    return;
                case obj.supportedFomats.hdf5
                    return;
            end
            b = false;
        end
        

        % -------------------------------------------------------
        function B = ne(obj, obj2)
            if obj==obj2
                B = false;
            else
                B = true;
            end
        end

        
        % -------------------------------------------------------
        function SetFileFormat(obj, fmt)
            obj.fileformat = fmt;
        end
        
        
        % -------------------------------------------------------
        function fmt = GetFileFormat(obj)
            fmt = obj.fileformat;
        end
        
        
        % -------------------------------------------------------
        function SetFilename(obj, fname)
            obj.filename = fname;
        end
        
        
        % -------------------------------------------------------
        function fname = GetFilename(obj)
            fname = obj.filename;
        end
        
        
        % -------------------------------------------------------
        function SetDataStorageScheme(obj, scheme)
            obj.dataStorageScheme = scheme;
        end
        
        
        % -------------------------------------------------------
        function scheme = GetDataStorageScheme(obj)
            scheme = obj.dataStorageScheme;
        end
        
        
        % -------------------------------------------------------
        function supportedFomats = GetSupportedFormats(obj)
            supportedFomats = obj.supportedFomats;
        end
                
    end
    
    
    %%%% Error/Warning handling
    methods
        
        % -------------------------------------------------------
        function err = SetError(obj, err0, errmsg)
            err = 0;
            if ~exist('errmsg','var')
                errmsg = '';
            end
            if (err0 > 0) || (obj.err > 0)
                k = -1;
            else
                k = 1;
            end
            obj.err = k * bitor(abs(obj.err), 2^abs(err0));
            if isempty(errmsg)
                return
            end
            obj.errmsgs{end+1} = errmsg;
            err = obj.err;
        end
        
        
        % -------------------------------------------------------
        function [err, errmsgs] = GetError(obj)
            err = 0;
            errmsgs = '';
            if isempty(obj)
                return
            end
            if isempty(obj.errmsgs)
                return
            end
            err = obj.err;
            errmsgs = obj.errmsgs;
        end
        
        
        % ----------------------------------------------------------------------------------
        function errmsg = GetErrorMsg(obj)
            errmsg = '';
            for ii = 1:length(obj.errmsgs)
                if isempty(obj.errmsgs{ii})
                    continue
                end
                if isempty(errmsg)
                    errmsg = sprintf('%s\n', obj.errmsgs{ii});
                else
                    errmsg = sprintf('%s%s\n', errmsg, obj.errmsgs{ii});
                end
            end
        end
        
        
        % -------------------------------------------------------
        function warn = SetWarning(obj, warn0, warnmsg)
            warn = 0;
            if ~exist('warnmsg','var')
                warnmsg = '';
            end
            if (warn0 <= 0) || (obj.warn < 0)
                k = -1;
            else
                k = 1;
            end
            obj.warn = k * bitor(abs(obj.warn), 2^abs(warn0));
            if isempty(warnmsg)
                return
            end
            obj.warnmsgs{end+1} = warnmsg;
            warn = obj.warn;
        end
        
        
        % -------------------------------------------------------
        function [warn, warnmsgs] = GetWarning(obj)
            warn = 0;
            warnmsgs = '';
            if isempty(obj)
                return
            end
            if isempty(obj.warnmsgs)
                return
            end
            warn = obj.warn;
            warnmsgs = obj.warnmsgs;
        end
        
        
        % ----------------------------------------------------------------------------------
        function warnmsg = GetWarningMsg(obj)
            warnmsg = '';
            for ii = 1:length(obj.warnmsgs)
                if isempty(obj.warnmsgs{ii})
                    continue
                end
                if isempty(warnmsg)
                    warnmsg = sprintf('%s\n', obj.warnmsgs{ii});
                else
                    warnmsg = sprintf('%s%s\n', warnmsg, obj.warnmsgs{ii});
                end
            end
        end
                
    end
    
end