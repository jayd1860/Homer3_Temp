classdef MetaDataTagsClass  < FileLoadSaveClass

    properties
        tags
    end

    methods
        
        % -------------------------------------------------------
        function obj = MetaDataTagsClass(varargin)
            % Set class properties not part of the SNIRF format
            obj.SetFileFormat('hdf5');
            obj.tags.SubjectID = 'default';
            obj.tags.MeasurementDate = datestr(now,29);
            obj.tags.MeasurementTime = datestr(now,'hh:mm:ss');
            obj.tags.LengthUnit = 'mm';
            obj.tags.TimeUnit = 'unknown';
            obj.tags.FrequencyUnit = 'unknown';
            obj.tags.AppName  = 'homer3-DataTree';

            if nargin==1 && ~isempty(varargin{1})
                obj.SetFilename(varargin{1});
                obj.Load();
            end
            if nargin==2
                obj.tags.LengthUnit = varargin{2};
            end
        end
    
        
        
        % -------------------------------------------------------
        function err = LoadHdf5(obj, fileobj, location)
            err = 0;
            
            % Arg 1
            if ~exist('fileobj','var') || (ischar(fileobj) && ~exist(fileobj,'file'))
                fileobj = '';
            end
            
            % Arg 2
            if ~exist('location', 'var') || isempty(location)
                obj.location = '/nirs/metaDataTags';
            else
                obj.location = location;
            end
                       
            % Error checking
            if ~isempty(fileobj) && ischar(fileobj)
                obj.SetFilename(fileobj);
            elseif isempty(fileobj)
                fileobj = obj.GetFilename();
            end
            if isempty(fileobj)
               err = -1;
               return;
            end
            
            
            %%%%%%%%%%%% Ready to load from file

            try
                % Reset tags
                obj.tags = struct();
                
                % Open group
                [gid, fid] = HDF5_GroupOpen(fileobj, obj.location);
                if isstruct(gid)
                    if gid.double < 0 
                        err = obj.SetError(0, 'metaDataTags field can''t be loaded');
                        return 
                    end
                end
                
                metaDataStruct = h5loadgroup(gid);
                tags = fieldnames(metaDataStruct); %#ok<*PROPLC>
                for ii=1:length(tags)
                    eval(sprintf('obj.tags.%s = metaDataStruct.%s;', tags{ii}, tags{ii}));
                end
                
                HDF5_GroupClose(fileobj, gid, fid);
                
            catch
                
                err = -1;
                
            end
            err = obj.ErrorCheck();

        end
        
        
        % -------------------------------------------------------
        function err = SaveHdf5(obj, fileobj, location) %#ok<*INUSD>
            err = 0;
            
            % Arg 1
            if ~exist('fileobj', 'var') || isempty(fileobj)
                error('Unable to save file. No file name given.')
            end
                       
            % Arg 2
            if ~exist('location', 'var') || isempty(location)
                location = '/nirs/metaDataTags';
            elseif location(1)~='/'
                location = ['/',location]; %#ok<*NASGU>
            end
            
            fid = HDF5_GetFileDescriptor(fileobj);
            if fid < 0
                err = -1;
                return;
            end
                        
            props = propnames(obj.tags);            
            for ii = 1:length(props)
                eval(sprintf('hdf5write_safe(fid, [location, ''/%s''], obj.tags.%s);', props{ii}, props{ii}));
            end
        end
        
        
        
        % -------------------------------------------------------
        function b = IsValid(obj)
            b = false;
            
            % Use latest required fields to determine if we're loading old
            % metaDataTag format version of SNIRF spec
            if ~isproperty(obj.tags, 'FrequencyUnit')
                return;
            end
            
            b = true;
        end

        
        
        % -------------------------------------------------------
        function B = eq(obj, obj2)
            B = false;
            props1 = propnames(obj.tags);
            props2 = propnames(obj2.tags);
            for ii=1:length(props1)
                if ~isproperty(obj2.tags, props1{ii})
                    return;
                end
                if eval(sprintf('~strcmp(obj.tags.%s, obj2.tags.%s)', props1{ii}, props1{ii}))
                    return;
                end
            end
            for ii=1:length(props2)
                if ~isproperty(obj.tags, props2{ii})
                    return;
                end
                if eval(sprintf('~strcmp(obj.tags.%s, obj2.tags.%s)', props2{ii}, props2{ii}))
                    return;
                end
            end
            B = true;
        end
        
        
        
        % -------------------------------------------------------
        function Add(obj, key, value) %#ok<INUSL>
            key(key==' ') = '';
            eval(sprintf('obj.tags.%s = value', key));
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function val = Get(obj, name)
            val = [];
            if ~exist('name', 'var')
                return;
            end
            if isfield(obj.tags, name)
                val = eval( sprintf('obj.tags.%s;', name) );
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function Set(obj, name, value)
            if ~exist('name', 'var') || ~exist('value', 'var')
                retrun
            end                                     
            eval( sprintf('obj.tags.%s = ''%s'';', name, value) )   
        end        
        
        % ----------------------------------------------------------------------------------
        function SetLengthUnit(obj, unit)
            if isempty(obj)
                return
            end
            obj.tags.LengthUnit = unit;
        end
        
        
        % ----------------------------------------------------------------------------------
        function val = GetLengthUnit(obj)
            val = '';
            if isempty(obj)
                return
            end
            val = obj.tags.LengthUnit;
        end
        
        
        % ----------------------------------------------------------------------------------
        function nbytes = MemoryRequired(obj)
            nbytes = 0;
            fields = propnames(obj.tags);
            for ii = 1:length(fields)
                nbytes = nbytes + eval(sprintf('sizeof(obj.tags.%s)', fields{ii}));
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function err = ErrorCheck(obj)
            % According to SNIRF spec, stim data is invalid if it has > 0 AND < 3 columns
            if ~isproperty(obj.tags, 'SubjectID')
                obj.SetError(-1, sprintf('%s:  SubjectID tag missing', obj.location));
            end
            if ~isproperty(obj.tags, 'MeasurementDate')
                obj.SetError(-2, sprintf('%s:  MeasurementDate tag missing', obj.location));
            end
            if ~isproperty(obj.tags, 'MeasurementTime')
                obj.SetError(-3, sprintf('%s:  MeasurementTime tag missing', obj.location));
            end
            if ~isproperty(obj.tags, 'LengthUnit')
                obj.SetError(-4, sprintf('%s:  LengthUnit tag missing', obj.location));
            end
            if ~isproperty(obj.tags, 'TimeUnit')
                obj.SetError(-5, sprintf('%s:  TimeUnit tag missing', obj.location));
            end
            if ~isproperty(obj.tags, 'FrequencyUnit')
                obj.SetError(-6, sprintf('%s:  FrequencyUnit tag missing', obj.location));
            end
            if ~isproperty(obj.tags, 'AppName')
                obj.SetError(-7, sprintf('%s:  AppName tag missing', obj.location));
            end
            err = obj.GetError();
        end
               
    end    
end

