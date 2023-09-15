classdef AuxClass < FileLoadSaveClass
    
    properties
        name
        dataTimeSeries
        time
        timeOffset
    end

    % Properties not part of the SNIRF spec. These parameters aren't loaded or saved to files
    properties (Access = private)
        debuglevel
    end    

    methods
        
        % -------------------------------------------------------
        function obj = AuxClass(varargin)
            % Set class properties not part of the SNIRF format
            obj.SetFileFormat('hdf5');

            obj.debuglevel = DebugLevel('none');
            
            obj.timeOffset = 0;
            if nargin==1
                if isa(varargin{1}, 'AuxClass')
                    obj = varargin{1}.copy();
                elseif ischar(varargin{1})
                    obj.SetFilename(varargin{1});
                    obj.Load();
                end
            elseif nargin==3
                obj.dataTimeSeries    = varargin{1};
                obj.time = varargin{2};
                obj.name = varargin{3};
            else
                obj.name = '';
                obj.dataTimeSeries = [];
                obj.time = [];
            end                        
        end
        
        
        % -------------------------------------------------------
        function err = LoadHdf5(obj, fileobj, location)
            
            % Arg 1
            if ~exist('fileobj','var') || (ischar(fileobj) && ~exist(fileobj,'file'))
                fileobj = '';
            end
            
            % Arg 2
            if ~exist('location', 'var') || isempty(location)
                obj.location = '/nirs/aux1';
            else
                obj.location = location;
            end
            
            % Error checking for file existence
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
                % Open group
                [gid, fid] = HDF5_GroupOpen(fileobj, obj.location);
                
                % Absence of optional aux field raises error > 0
                if isstruct(gid)
                if gid.double < 0
                        err = obj.SetError(0, sprintf('aux field %s field can''t be loaded', obj.location));
                        return 
                end
                end
                
                obj.name            = HDF5_DatasetLoad(gid, 'name');
                obj.dataTimeSeries  = HDF5_DatasetLoad(gid, 'dataTimeSeries');
                obj.time            = HDF5_DatasetLoad(gid, 'time');
                obj.timeOffset      = HDF5_DatasetLoad(gid, 'timeOffset');
               
                % Name should not be loaded as a 1x1 cell array, but some
                % Python interfaces lead to it being saved this way.
                %
                % This is due to the string being saved in fixed vs.
                % variable length format. See: https://support.hdfgroup.org/HDF5/doc1.6/UG/11_Datatypes.html
                %
                % As of version 1.0 of the SNIRF specification, this is not
                % an issue of spec compliance.
                if iscell(obj.name) && length(obj.name) == 1
                    obj.name = obj.name{1};
                end
                
                % Close group
                HDF5_GroupClose(fileobj, gid, fid);
                
            catch
                
                if isstruct(gid)
                    if gid.double < 0 
                        obj.SetError(0, sprintf('aux field %s field can''t be loaded', obj.location));
                    end
                else
                    obj.SetError(7, sprintf('aux field %s field can''t be loaded', obj.location));
                end
                
            end
            
            err = obj.ErrorCheck();
            
        end

        
        % -------------------------------------------------------
        function err = SaveHdf5(obj, fileobj, location)
            err = 0;
            
            % Arg 1
            if ~exist('fileobj', 'var') || isempty(fileobj)
                error('Unable to save file. No file name given.')
            end
            
            % Arg 2
            if ~exist('location', 'var') || isempty(location)
                location = '/nirs/aux1';
            elseif location(1)~='/'
                location = ['/',location];
            end
            
            % Convert file object to HDF5 file descriptor
            fid = HDF5_GetFileDescriptor(fileobj);
            if fid < 0
                err = -1;
                return;
            end
            
            if obj.debuglevel.Get() == obj.debuglevel.SimulateBadData()
                obj.SimulateBadData();
            end
            
            hdf5write_safe(fid, [location, '/name'], obj.name);
            hdf5write_safe(fid, [location, '/dataTimeSeries'], obj.dataTimeSeries, 'array');
            hdf5write_safe(fid, [location, '/time'], obj.time, 'vector');
            hdf5write_safe(fid, [location, '/timeOffset'], obj.timeOffset, 'vector');
        end
        
        
        % ---------------------------------------------------------
        function SetDataTimeSeries(obj, val)
            if ~exist('val','var')
                return;
            end
            obj.dataTimeSeries = val;
        end
        
        
        % -------------------------------------------------------
        function d = GetDataTimeSeries(obj)
            d = obj.dataTimeSeries;
        end
        
        
        % -------------------------------------------------------
        function name = GetName(obj)
            name = obj.name;
        end
        
        
        % -------------------------------------------------------
        function val = GetTime(obj)
            val = obj.time;
        end
        
        
        % ----------------------------------------------------------------------------------
        function Copy(obj, obj2)
            if isempty(obj)
                obj = AuxClass();
            end
            if ~isa(obj2, 'AuxClass')
                return;
            end
            obj.dataTimeSeries  = obj2.dataTimeSeries;
            obj.time            = obj2.time;
            obj.timeOffset      = obj2.timeOffset;
        end
        
        
        % -------------------------------------------------------
        function B = eq(obj, obj2)
            B = false;
            if ~strcmp(obj.name, obj2.name)
                return;
            end
            if ~all(obj.dataTimeSeries(:)==obj2.dataTimeSeries(:))
                return;
            end
            if ~all(obj.time(:)==obj2.time(:))
                return;
            end
            if obj.timeOffset(:)~=obj2.timeOffset
                return;
            end
            B = true;
        end
        
        
        % ----------------------------------------------------------------------------------
        function nbytes = MemoryRequired(obj)
            nbytes = 0;
            if isempty(obj)
                return
            end
            nbytes = sizeof(obj.name) + sizeof(obj.dataTimeSeries) + sizeof(obj.time) + sizeof(obj.timeOffset);
        end
        
        
        % ----------------------------------------------------------------------------------
        function b = IsEmpty(obj)
            b = true;
            if isempty(obj)
                return
            end
            if isempty(obj.name)
                return
            end
            if isempty(obj.dataTimeSeries)
                return
            end
            if isempty(obj.time)
                return
            end
            if length(obj.dataTimeSeries) ~= length(obj.time)
                return
            end
            b = false;
        end
        
        
        % ----------------------------------------------------------------------------------
        function err = ErrorCheck(obj)
            if isempty(obj.name)
                obj.SetError(2, sprintf('%s:  field is empty', [obj.location, '/name']));
            end
            if isempty(obj.dataTimeSeries)
                obj.SetError(3, sprintf('%s:  field is empty', [obj.location, '/dataTimeSeries']));
            end
            if isempty(obj.time)
                obj.SetError(4, sprintf('%s:  field is empty', [obj.location, '/time']));
            end
            if length(obj.dataTimeSeries) ~= length(obj.time)
                obj.SetError(5, sprintf('%s:  size does not equal size of dataTimeSeries', [obj.location, '/time']));
            end
            if ~ischar(obj.name)
                obj.SetError(6, sprintf('%s:  field is empty', [obj.location, '/name']));
            end
            err = obj.GetError();
        end
        
        
        % ----------------------------------------------------------------------------------
        function SimulateBadData(obj)
            obj.dataTimeSeries(end,:) = [];
        end
        
    end
    
end

