classdef TreeNodeClass < handle
    
    properties % (Access = private)
        name;
        type;
        iGroup;
        iSubj;
        iSess;
        iRun;
        iFile;
        children;
        procStream;
        err;
        CondNames;
        updateParentGui;
    end
    
    properties
        inputVars
        DEBUG
        path
        logger
        pathOutputAlt        
        outputDirname
        cfg
    end
    
    methods        
        
        % ---------------------------------------------------------------------------------
        function obj = TreeNodeClass(arg)
            global logger
            global cfg

            obj.logger = InitLogger(logger);
            obj.cfg    = InitConfig(cfg);

            obj.DEBUG = 0;
            
            obj.name = '';
            
            obj.iGroup = 0;
            obj.iSubj = 0;
            obj.iSess = 0;
            obj.iRun = 0;
            
            obj.type = '';
            obj.procStream = ProcStreamClass();
            obj.err = 0;
            obj.CondNames = {};
            obj.path = filesepStandard(pwd);            
            
            obj.outputDirname = filesepStandard(obj.cfg.GetValue('Output Folder Name'), 'nameonly:dir');

            obj.InitParentAppFunc();
            obj.children = [];
            
            % If this constructor is called from this class' copy method,
            % then we want to exit before we obliterate the persistent
            % variables (only one copy of which is shared across all objects 
            % of this class, like a static var in C++). 
            % 
            % Essentially if a copy arg is passed this constructor
            % is used as a copy constructor (to borrow C++ terminology)
            %
            if nargin==1
                if iscell(arg) && ~isempty(arg) 
                    arg = arg{1};
                end
                if ischar(arg) && strcmp(arg,'copy')
                    return;
                end
            end
            obj.CondColTbl('init');
            obj.GroupDataLoadWarnings();            
        end
        
    end
    
    
    methods
        
        % ---------------------------------------------------------------------------------
        function err = LoadProcStreamConfigFile(obj, filename)
            err = obj.procStream.LoadConfigFile(filename, class(obj));
        end        
        
                
        % ---------------------------------------------------------------------------------
        function SaveProcStreamConfigFile(obj, filename)
            obj.procStream.SaveConfigFile(filename, class(obj));
        end        
                
        
        % ---------------------------------------------------------------------------------
        function CreateProcStreamDefault(obj)
            obj.procStream.CreateDefault()
        end
        
        
        % ---------------------------------------------------------------------------------
        function procStream = GetProcStreamDefault(obj)
            procStream = obj.procStream.GetDefault(class(obj));
        end 
       
    end
    
    
    methods
        
        % ----------------------------------------------------------------------------------
        % Override == operator: 
        % ----------------------------------------------------------------------------------
        function B = eq(obj1, obj2)
            B = equivalent(obj1, obj2);
        end

        
        % ----------------------------------------------------------------------------------
        % Override ~= operator
        % ----------------------------------------------------------------------------------
        function B = ne(obj1, obj2)
            B = ~equivalent(obj1, obj2);
        end
        
        
        % ----------------------------------------------------------------------------------
        % Copy function to do deep copy
        % ----------------------------------------------------------------------------------
        function objnew = copy(obj)
            switch(class(obj))
                case 'RunClass'
                    objnew = RunClass('copy');
                case 'SessClass'
                    objnew = SessClass('copy');
                case 'SubjClass'
                    objnew = SubjClass('copy');
                case 'GroupClass'
                    objnew = GroupClass('copy');
                case ''
            end
            objnew.name = obj.name;
            objnew.type = obj.type;
            objnew.err = obj.err;
            objnew.CondNames = obj.CondNames;
            objnew.procStream.Copy(obj.procStream, obj.GetOutputFilename);
        end
        
               
        % ----------------------------------------------------------------------------------
        % Copy processing params (procInut and procResult) from
        % obj2 to obj
        % ----------------------------------------------------------------------------------
        function Copy(obj, obj2, conditional)
            if nargin==2 || strcmp(conditional, 'unconditional')
                obj.name = obj2.name;
                obj.path = obj2.path;
                obj.outputDirname = obj2.outputDirname;
                obj.type = obj2.type;
                obj.iGroup = obj2.iGroup;
                obj.iSubj = obj2.iSubj;
                obj.iSess = obj2.iSess;
                obj.iRun = obj2.iRun;
            end
            if ~isempty(obj2.procStream)
                [pathname, filename] = fileparts([obj.path, obj.GetOutputFilename()]);                
                
                % Recreate the same relative dir structure under derived output
                % folder as exists directly under the group folder
                if ispathvalid([filesepStandard(obj.path), obj.name], 'dir')
                    pathname = [filesepStandard(pathname), filename];
                end
                obj.procStream.SaveInitOutput(pathname, filename);
                obj.procStream.Copy(obj2.procStream, [obj.path, obj.GetOutputFilename()]);
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function Reset(obj)
            obj.procStream.output.Reset([obj.path, obj.GetOutputFilename()]);
            delete([obj.path, obj.GetOutputFilename(), '*.txt']);
            delete([obj.path, 'tCCAfilter_*.txt'])
        end
        
        
        % ----------------------------------------------------------------------------------
        % 
        % ----------------------------------------------------------------------------------
        function options_s = parseSaveOptions(~, options)
            options_s = struct('derived',false, 'acquired',false);
            C = str2cell(options, {':',',','+',' '});
            
            for ii=1:length(C)
                if isproperty(options_s, C{ii})
                    eval( sprintf('options_s.%s = true;', C{ii}) );
                end
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function InitParentAppFunc(obj)
            global maingui
            if isfield(maingui, 'Update')
                obj.updateParentGui = maingui.Update;
            end
        end
        

        % ----------------------------------------------------------------------------------
        function SetIndexID(obj, iGroup, iSubj, iSess, iRun)
            if nargin>1
                obj.iGroup = iGroup;
            end            
            if nargin>2
                obj.iSubj = iSubj;
            end
            if nargin>3
                obj.iSess = iSess;
            end
            if nargin>4
                obj.iRun = iRun;
            end
        end
        
        
        % ----------------------------------------------------------
        function idx = FindProcElem(obj, name)
            idx = [];
            if strcmp(name, obj.GetName())
                idx = obj.GetIndexID();
                return;
            end
            if strcmp(name, obj.GetFilename())
                idx = obj.GetIndexID();
                return;
            end
            for ii = 1:length(obj.children)
                if strcmp(name, obj.children(ii).GetName())
                    idx = obj.children(ii).GetIndexID();
                    return;
                end
                if strcmp(name, obj.children(ii).GetFilename())
                    idx = obj.children(ii).GetIndexID();
                    return;
                end
                idx = obj.children(ii).FindProcElem(name);
                if ~isempty(idx)
                    return;
                end
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function SetPath(obj, dirname)
            obj.path = dirname;
            
            % In case there's not enough disk space in the current
            % group folder, we have a alternative path that can be 
            % set independently for saving group results. By default 
            % it is set to root group folder. 
            obj.pathOutputAlt = obj.path;
        end
        
        
        % ----------------------------------------------------------------------------------
        function SetPathOutput(obj, dirname)
            % In case there's not enough disk space in the current
            % group folder, we have a alternative path that can be 
            % set independently for saving group results. By default 
            % it is set to root group folder. 
            obj.pathOutputAlt = dirname;
        end
        
        
        % ----------------------------------------------------------------------------------
        function SetProcFlag(obj)
            if obj.procStream.output.IsEmpty()
                return;
            end
            if isa(obj, 'GroupClass')
                obj.GroupsProcFlags(obj.iGroup, 1);
            elseif isa(obj, 'SubjClass')
                obj.SubjsProcFlags(obj.iGroup, obj.iSubj, 1);
            elseif isa(obj, 'SessClass')
                obj.SubjsProcFlags(obj.iGroup, obj.iSubj, obj.iSess, 1);
            elseif isa(obj, 'RunClass')
                obj.RunsProcFlags(obj.iGroup, obj.iSubj, obj.iSess, obj.iRun, 1);
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function idx = GetIndexID(obj)
            idx = [obj.iGroup, obj.iSubj, obj.iSess, obj.iRun];
        end
        
        
        % ----------------------------------------------------------------------------------
        function b = IsGroup(obj)
            if strcmp('group', obj.type)
                b = true;
            else
                b = false;
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function b = IsSubj(obj)
            if strcmp('subj', obj.type)
                b = true;
            else
                b = false;
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function b = IsSess(obj)
            if strcmp('sess', obj.type)
                b = true;
            else
                b = false;
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function b = IsRun(obj)
            if strcmp('run', obj.type)
                b = true;
            else
                b = false;
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function b = IsSame(obj, iGroup, iSubj, iSess, iRun)
            b = false;
            if isempty(obj)
                return;
            end
            if iGroup==obj.iGroup && iSubj==obj.iSubj && iSess==obj.iSess && iRun==obj.iRun
                b = true;
            end                
        end
                
    end
        
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods for setting/getting TreeNode procStream output
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
               
        % ----------------------------------------------------------------------------------
        function t = GetTHRF(obj, iBlk)
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk=1;
            end
            t = obj.procStream.output.GetTHRF(iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function d = GetRawData(~)            
            d = [];
        end
        
        
        % ----------------------------------------------------------------------------------
        function dod = GetDod(obj, iBlk)
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk=1;
            end
            dod = obj.procStream.output.GetDataTimeCourse('dod',iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function dc = GetDc(obj, iBlk)
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk=1;
            end
            dc = obj.procStream.output.GetDataTimeCourse('dc',iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function dodAvg = GetDodAvg(obj, condition, iBlk)
            if ~exist('condition','var') || isempty(condition)
                icond = 1:length(obj.GetConditions());
            elseif ischar(condition)
                icond = obj.GetConditionIdx(condition);
            else
                icond = condition;
            end
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk=1;
            end
            dodAvg = obj.procStream.output.GetDodAvg('dodAvg', icond, iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function dcAvg = GetDcAvg(obj, condition, iBlk)
            if ~exist('condition','var') || isempty(condition)
                icond = 1:length(obj.GetConditions());
            elseif ischar(condition)
                icond = obj.GetConditionIdx(condition);
            else
                icond = condition;
            end
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk=1;
            end
            dcAvg = obj.procStream.output.GetDcAvg('dcAvg', icond, iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function dodAvgStd = GetDodAvgStd(obj, condition, iBlk)
            if ~exist('condition','var') || isempty(condition)
                condition = 1:length(obj.GetConditions());
            end
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk=1;
            end
            dodAvgStd = obj.procStream.output.GetDodAvg('dodAvgStd', condition, iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function dcAvgStd = GetDcAvgStd(obj, condition, iBlk)
            if ~exist('condition','var') || isempty(condition)
                condition = 1:length(obj.GetConditions());
            end
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk=1;
            end
            dcAvgStd = obj.procStream.output.GetDcAvg('dcAvgStd', condition, iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function dodSum2 = GetDodSum2(obj, condition, iBlk)
            if ~exist('condition','var') || isempty(condition)
                condition = 1:length(obj.GetConditions());
            end
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk=1;
            end
            dodSum2 = obj.procStream.output.GetDodSum2('dodSum2', condition, iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function dcSum2 = GetDcSum2(obj, condition, iBlk)
            if ~exist('condition','var') || isempty(condition)
                condition = 1:length(obj.GetConditions());
            end
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk=1;
            end
            dcSum2 = obj.procStream.output.GetDcSum2('dcSum2', condition, iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function nTrials = GetNtrials(obj, iBlk)
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk = 1;
            end
            nTrials = obj.procStream.output.GetNtrials(iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function pValues = GetPvalues(obj, iBlk)
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk = [];
            end
            pValues = obj.procStream.output.GetVar('pValues');
            if ~isempty(iBlk) && iBlk<=length(pValues)
                pValues = pValues{iBlk};
            end
        end
        
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods for retrieving TreeNode params
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        
        % ----------------------------------------------------------------------------------
        function s = GetStims(~, ~)
            s = [];
        end
        
        
        % ----------------------------------------------------------------------------------
        function CondNames = GetConditions(obj)
            CondNames = obj.CondNames;
        end

        
        % ----------------------------------------------------------------------------------
        function RenameCondition(obj, oldname, newname)
            % Function to rename a condition. Important to remeber that changing the
            % condition involves 2 distinct well defined steps:
            %   a) For the current element change the name of the specified (old)
            %      condition for ONLY for ALL the acquired data elements under the
            %      currElem, be it session, subj, or group . In this step we DO NOT TOUCH
            %      the condition names of the session, subject or group .
            %   b) Rebuild condition names and tables of all the tree nodes group, subjects
            %      and sessions same as if you were loading during Homer3 startup from the
            %      acquired data.
            %
            if ~exist('oldname','var') || ~ischar(oldname)
                return;
            end
            if ~exist('newname','var')  || ~ischar(newname)
                return;
            end            
            newname = obj.ErrCheckNewCondName(newname);
            if obj.err ~= 0
                return;
            end
            for ii = 1:length(obj.children)
                obj.children(ii).RenameCondition(oldname, newname);
            end
        end
        
                
        % ----------------------------------------------------------------------------------
        function SetConditions(obj, CondNames)
            if isempty(obj)
                return;
            end
            
            % First get global et of conditions across all runs and
            % subjects
            CondNames = {};
            for ii = 1:length(obj.children)
                obj.children(ii).SetConditions();
                CondNames = [CondNames, obj.children(ii).GetConditions()];
            end
            obj.CondNames    = unique(CondNames);
           
           	if nargin == 1
           		return
           	end
           		
            % Now that we have all conditions, set the conditions across 
            % the whole group to these
            for ii = 1:length(obj.children)
                obj.children(ii).SetConditions(obj.CondNames);
            end            
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function idx = GetConditionIdx(obj, CondName)
            C = obj.GetConditions();
            idx = find(strcmp(C, CondName));
        end
        
        
        % ----------------------------------------------------------------------------------
        function varval = GetVar(obj, varname)
            varval = [];
            if isproperty(obj, varname)
                varval = eval( sprintf('obj.%s', varname) );
            end
            if isempty(varval)
                varval = obj.procStream.GetVar(varname);
            end
        end
        
               
        % ----------------------------------------------------------------------------------
        function AddStims(~, ~, ~)
            return;
        end        
        
        
        % ----------------------------------------------------------------------------------
        function DeleteStims(~, ~)
            return;
        end
        
        
        % ----------------------------------------------------------------------------------
        function ToggleStims(~, ~)
            return;
        end
        
        
        % ----------------------------------------------------------------------------------
        function SetStimDuration(~, ~, ~)
            return;
        end
    
        
        % ----------------------------------------------------------------------------------
        function duration = GetStimDuration(~, ~)
            duration = [];            
        end
        
        
        % ----------------------------------------------------------------------------------
        function data = GetStimData(~, ~)
            data = [];
        end
        
        
        % ----------------------------------------------------------------------------------
        function val = GetStimDataLabels(~, ~)
            val = {};
        end
                        
        
        % ----------------------------------------------------------------------------------
        function newname = ErrCheckNewCondName(obj, newname)
            msg1 = sprintf('Condition name ''%s'' already exists. New name must be unique. Do you want to choose another name?', newname);
            while ismember(newname, obj.CondNames)                
                q = menu(msg1,'YES','NO');
                if q==2
                    obj.err = -1;
                    return;
                end
                newname = inputdlg({'New Condition Name'}, 'New Condition Name');
                if isempty(newname) || isempty(newname{1})
                    obj.err = 1;
                    return;
                end
                newname = newname{1};
            end
            msg2 = sprintf('Condition name is not valid. New name must be character string. Do you want to choose another name?');
            while ~ischar(newname)                
                q = menu(msg2,'YES','NO');
                if q==2
                    obj.err = -1;
                    return;
                end
                newname = inputdlg({'New Condition Name'}, 'New Condition Name');
                if isempty(newname) || isempty(newname{1})
                    obj.err = 1;
                    return;
                end
                newname = newname{1};
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function err = GetErrStatus(obj)
            err = obj.err;
            
            % Reset error status
            obj.err = 0;
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function y = reshape_y(obj, y, MeasList)
            yold = y;
            lst1 = find(MeasList(:,4)==1);
            Lambda = obj.GetWls();

            if ndims(y)==2 %#ok<*ISMAT>
                y = zeros(size(yold,1),length(lst1),length(Lambda));
            elseif ndims(y)==3
                y = zeros(size(yold,1),length(lst1),length(Lambda),size(yold,3));
            end
            
            for iML = 1:length(lst1)
                for iLambda = 1:length(Lambda)
                    idx = find(MeasList(:,1)==MeasList(lst1(iML),1) & ...
                               MeasList(:,2)==MeasList(lst1(iML),2) & ...
                               MeasList(:,4)==iLambda );
                    if ndims(yold)==2
                        y(:,iML,iLambda) = yold(:,idx);
                    elseif ndims(yold)==3
                        y(:,iML,iLambda,:) = yold(:,idx,:);
                    end
                end
            end            
        end
        
        
        % ----------------------------------------------------------------------------------
        function name = GetName(obj)
            name = '';
            if isempty(obj)
                return;
            end
            name = obj.name;
        end
        
        
        % ----------------------------------------------------------------------------------
        function SetName(obj, name)
            if isempty(obj)
                return;
            end
            obj.name = name;
        end
        
        
        % ----------------------------------------------------------------------------------
        function name = GetFileName(obj)
            name = '';
            if isempty(obj)
                return;
            end
            [~, fname, ext] = fileparts(obj.name);
            name = [fname, ext];
        end
        
        
        % ----------------------------------------------------------------------------------
        function d = GetDataTimeSeries(~, ~, ~)
            d = [];
        end

        
        % ----------------------------------------------------------------------------------
        function t = GetTime(~, ~)
            t = [];
        end

        
        % ----------------------------------------------------------------------------------
        function aux = GetAux(~)
            aux = [];
        end

        
        % ----------------------------------------------------------------------------------
        function t = GetAuxiliaryTime(~, ~)
            t = [];
        end

        
        % ----------------------------------------------------------------------------------
        function t = GetTimeCombined(~)
            t = [];
        end
        
        
        % ----------------------------------------------------------------------------------
        function t = GetTincAuto(~, ~)
            t = [];
        end
        
        
        % ----------------------------------------------------------------------------------
        function t = GetTincAutoCh(~, ~)
            t = [];
        end
        
        
        % ----------------------------------------------------------------------------------
        function t = GetTincMan(~, ~)
            t = [];
        end

        
        % ----------------------------------------------------------------------------------
        function SetTincMan(~, ~, ~, ~)
            
        end
               
    end
        
    
    methods
        
        % ----------------------------------------------------------------------------------
        function err = Load(obj)
            err = -1;
            if isempty(obj)
                return
            end
            err = obj.LoadSubBranch(); %#ok<*MCNPN>
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function Calc(obj)            
            
            % Make variables in this subject available to processing stream input
            obj.procStream.input.LoadVars(obj.inputVars);

            % Calculate processing stream
            fcalls = obj.procStream.Calc([obj.path, obj.GetOutputFilename()]); %#ok<NASGU>
            
        end
        
        

        % ----------------------------------------------------------------------------------
        function ExportProcStreamFunctionsInit(obj)
            cfg = ConfigFileClass();
            val = cfg.GetValue('Export Processing Stream Functions');
            if strcmpi(val, 'yes')
                obj.procStream.ExportProcStreamFunctions(true);
            elseif strcmpi(val, 'no')
                obj.procStream.ExportProcStreamFunctions(false);
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function ExportProcStreamFunctionsClose(obj)
            if ~obj.procStream.ExportProcStreamFunctions()
                if ispathvalid([obj.path, obj.outputDirname, 'ProcStreamSummary.txt'])
                    try
                        delete([obj.path, obj.outputDirname, 'ProcStreamSummary.txt'])
                    catch
                    end
                end
                return
            end
            fid = fopen([obj.path, obj.outputDirname, 'ProcStreamSummary.txt'], 'w');
            fprintf(fid, 'SUMMARY :\n');
            fclose(fid);
        end
        
        
                
        % ----------------------------------------------------------------------------------
        function FreeMemory(obj)
            if isempty(obj)
                return
            end
            obj.FreeMemorySubBranch();
            obj.procStream.FreeMemory(obj.GetOutputFilename);
        end
        

        % ----------------------------------------------------------------------------------
        function ExportHRF(obj, procElemSelect, iBlk)
            if ~exist('procElemSelect','var') || isempty(procElemSelect)
                q = MenuBox('Export only current element OR current element and all current element''s data ?', ...
                            {'Current data element only','Current element and all it''s data','Cancel'});
                if q==1
                    procElemSelect  = 'current';
                elseif q==2
                    procElemSelect  = 'all';
                else
                    return
                end
            end
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk = 1;
            end

            if strcmp(procElemSelect, 'all')
                for ii = 1:length(obj.children)
                    obj.children(ii).ExportHRF('all', iBlk);
                end
            end            
            obj.logger.Write('Exporting  %s', [obj.path, obj.GetOutputFilename()]);

            % Update call application GUI using it's generic Update function
            if ~isempty(obj.updateParentGui)
                obj.updateParentGui('DataTreeClass', [obj.iGroup, obj.iSubj, obj.iSess, obj.iRun]);
            end
            
            % Load derived data and export it
            obj.procStream.Load([obj.path, obj.GetOutputFilename()]);
            if ~obj.DEBUG
                obj.procStream.ExportHRF([obj.path, obj.GetOutputFilename()], obj.CondNames, iBlk);
            end
            pause(.5);
        end
    
        
        % ----------------------------------------------------------------------------------
        function ExportMeanHRF(obj, procElemSelect, trange, iBlk)
            if ~exist('procElemSelect','var') || isempty(procElemSelect)
                q = MenuBox('Export only current element OR current element and all current element''s data ?', ...
                            {'Current data element only','Current element and all it''s data','Cancel'});
                if q==1
                    procElemSelect  = 'current';
                elseif q==2
                    procElemSelect  = 'all';
                else
                    return
                end
            end
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk = 1;
            end

            if strcmp(procElemSelect, 'all')
                for ii = 1:length(obj.children)
                    obj.children(ii).ExportMeanHRF(procElemSelect, trange, iBlk);
                end
            end            
            obj.logger.Write('Exporting HRF mean %s', [obj.path, obj.GetOutputFilename()]);

            % Update call application GUI using it's generic Update function
            if ~isempty(obj.updateParentGui)
                obj.updateParentGui('DataTreeClass', [obj.iGroup, obj.iSubj, obj.iSess, obj.iRun]);
            end
            
            % Load derived data and export it
            obj.procStream.Load([obj.path, obj.GetOutputFilename()]);
            if ~obj.DEBUG
                obj.procStream.ExportMeanHRF([obj.path, obj.GetOutputFilename()], obj.CondNames, trange, iBlk);
            end
            pause(.5);
        end
    
        
        
        % ----------------------------------------------------------------------------------
        function tblcells = ExportMeanHRF_Alt(obj, procElemSelect, trange, iBlk)
            tblcells = [];
            if isempty(obj.children)
                return
            end
            if ~exist('trange','var') || isempty(trange)
                trange = [];
            end
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk = 1;
            end
            
            
            %%%%% First export child data if user asked  
            nChild = length(obj.children);            
            if strcmp(procElemSelect, 'all')
                for iChild = 1:nChild
                    obj.children(iChild).ExportMeanHRF(procElemSelect, trange, iBlk);
                end
            end

            
            %%%%% Now export parent data 
            obj.logger.Write('Exporting HRF mean %s', [obj.path, obj.GetOutputFilename()]);

            nCh   = obj.procStream.GetNumChForOneCondition(iBlk);
            nCond = length(obj.CondNames);

            % Determine table dimensions            
            nHdrRows = 3;               % Blank line + name of columns
            nHdrCols = 2;               % Condition name + subject name
            nDataRows = nChild*nCond;    
            nDataCols = nCh;                 % Number of channels for one condition (for example, if data type is Hb Conc: (HbO + HbR + HbT) * num of SD pairs)
            nTblRows = nDataRows + nHdrRows;
            nTblCols = nDataCols + nHdrCols;
            cellwidthCond = max(length('Condition'), obj.CondNameSizeMax());
            cellwidthChild = max(length(sprintf('%s Name', obj.GetChildTypeLabel())), obj.NameSizeMax());
            
            % Initialize 2D array of TableCell objects with the above row * column dimensions            
            tblcells = repmat(TableCell(), nTblRows, nTblCols);
            
            % Header row: Condition, Subject Name, HbO,1,1, HbR,1,1, HbT,1,1, ...
            tblcells(2,1) = TableCell('Condition', cellwidthCond);
            tblcells(2,2) = TableCell(sprintf('%s Name',  obj.GetChildTypeLabel()), cellwidthChild);
            [tblcells(2,3:end), cellwidthData] = obj.procStream.GenerateTableCellsHeader_MeanHRF(iBlk);
            
            % Generate data rows
            for iChild = 1:nChild
                rowIdxStart = ((iChild-1)*nCond)+1 + nHdrRows;
                rowIdxEnd   = rowIdxStart + nCond - 1;
                
                c = obj.children(iChild).GenerateTableCellsHeader_MeanHRF(cellwidthCond, cellwidthChild);
                if isempty(c)
                    continue
                end
                tblcells(rowIdxStart:rowIdxEnd, 1:2) = c;
                
                c = obj.children(iChild).GenerateTableCells_MeanHRF(trange, cellwidthData, iBlk);
                if isempty(c)
                    continue
                end
                tblcells(rowIdxStart:rowIdxEnd, 3:nTblCols) = c;
            end
            
            % Update call application GUI using it's generic Update function
            if ~isempty(obj.updateParentGui)
                obj.updateParentGui('DataTreeClass', [obj.iGroup, obj.iSubj, obj.iSess, obj.iRun]);
            end
            
            % Create ExportTable initialized with the filled in 2D TableCell array. 
            % ExportTable object is what actually does the exporting to a file.
            obj.procStream.ExportMeanHRF_Alt([obj.path, obj.GetOutputFilename()], tblcells);
            pause(.5);
        end
                        
        
        
        % ----------------------------------------------------------------------------------
        function tblcells = GenerateTableCellsHeader_MeanHRF(obj, widthCond, widthChild)
            tblcells = repmat(TableCell(), length(obj.CondNames), 2);
            for iCond = 1:length(obj.CondNames)
                % First 2 columns contain condition name and group, subject or session name
                tblcells(iCond, 1) = TableCell(obj.CondNames{iCond}, widthCond);
                tblcells(iCond, 2) = TableCell(obj.name, widthChild);
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function tblcells = GenerateTableCells_MeanHRF(obj, trange, width, iBlk)
            if ~exist('trange','var') || isempty(trange)
                trange = [0,0];
            end
            if ~exist('width','var') || isempty(width)
                width = 12;
            end
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk = 1;
            end
            obj.Load();
            tblcells = obj.procStream.GenerateTableCells_MeanHRF_Alt(obj.name, obj.CondNames, trange, width, iBlk);
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function n = CondNameSizeMax(obj)
            n = 0;
            if isempty(obj.CondNames)
                return;
            end
            for ii = 1:length(obj.CondNames)
                if length(obj.CondNames{ii}) > n
                    n = length(obj.CondNames{ii});
                end
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function n = NameSizeMax(obj)
            n = 0;
            if isempty(obj.children)
                return;
            end
            for ii = 1:length(obj.children)
                if length(obj.children(ii).name) > n
                    n = length(obj.children(ii).name);
                end
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function ApplyParamEditToAll(obj, iFcall, iParam, val)
            % Figure out which level we are: group, subj, sess, or run
            if obj.iSubj==0 && obj.iSess==0 && obj.iRun==0
                for ii = 1:length(obj.subjs)
                    obj.subjs(ii).procStream.EditParam(iFcall, iParam, val);
                end
             elseif obj.iSubj>0 && obj.iSess>0 && obj.iRun==0
                for ii = 1:length(obj.subjs)
                    for jj = 1:length(obj.subjs(ii).sess)
                        obj.subjs(ii).sess(jj).procStream.EditParam(iFcall, iParam, val);
                    end
                end
            elseif obj.iSubj>0 && obj.iSess>0 && obj.iRun>0
                for ii = 1:length(obj.subjs)
                    for jj = 1:length(obj.subjs(ii).sess)
                        for kk = 1:length(obj.subjs(ii).sess(jj).runs)
                            obj.subjs(ii).sess(jj).runs(kk).procStream.EditParam(iFcall, iParam, val);
                        end
                    end
                end
            end
        end
        


        % ----------------------------------------------------------------------------------
        function typelabel = GetChildTypeLabel(obj)
            typelabel = '';
            if isempty(obj)
                return;
            end
            if isempty(obj.children)
                return;
            end
            temp = class(obj.children(1));
            k = strfind(temp, 'Class');
            typelabel = temp(1:k-1);            
        end        
        
        
        
        % ----------------------------------------------------------------------------------
        function b = HaveOutput(obj)
            b = false;
            for ii = 1:length(obj.children)
                b = obj.children(ii).HaveOutput();
                if b
                    break;
                end
            end
        end
        
        
                
        % ----------------------------------------------------------------------------------
        function nbytes = MemoryRequired(obj)
            if isempty(obj)
                return;
            end            
            nbytes = obj.procStream.MemoryRequired();
        end
        
        
        % ----------------------------------------------------------------------------------
        function filename = GetOutputFilename(obj, options)
            filename = '';
            if isempty(obj)
                return;
            end
            if ~exist('options','var')
                options = '';
            end
            filename0 = obj.SaveMemorySpace(obj.name);
            if isempty(filename0)
                return;
            end
            if optionExists(options, 'legacy')
                outputDirname = ''; %#ok<*PROPLC>
            else
                outputDirname = obj.outputDirname;
            end
            [p, f] = fileparts([outputDirname, filename0]);
            filename = [filesepStandard(p, 'nameonly:dir'), f];            
        end
        
        
        % ----------------------------------------------------------------------------------
        function filename = GetFilename(obj)
            filename = '';
            if isempty(obj)
                return;
            end
            filename = obj.SaveMemorySpace(obj.name);
            if isempty(filename)
                return;
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function status = Mismatch(obj, obj2)
            status = 0;
            if exist('obj2','var')                
                if obj == obj2
                    return
                end
            end
            status = 1;
                        
            configFileOptions =  MenuBox('',{},[],[], 'dontAskAgainOptions');
            choices = { ...
                sprintf('Continue Loading'); ...
                sprintf('Quit Loading'); ...
            };
        
            if exist('obj2','var')
                msg{1} = sprintf('WARNING: Saved processing data for %s "%s" does not match this group folder. ', obj.type, obj.name);
                msg{2} = sprintf('Are you sure this saved data belongs to this group folder?');
            else
                msg{1} = sprintf('WARNING: The %s "%s" does not match the saved group data. ', obj.type, obj.name);
                msg{2} = sprintf('Are you sure the saved data belongs to this group folder?');
            end
            obj.logger.Write([msg{:}])
            if strcmp(obj.GroupDataLoadWarnings, configFileOptions{1})
                return;
            end
            selection = MenuBox(msg, choices, [], [], 'dontAskAgainOptions');
            if length(selection)<2
                selection(2)=0;
            end
            
            % Find out if config value does not equal current selection. If
            % not then reset config value
            if selection(2)>0
                if ~strcmp(obj.GroupDataLoadWarnings, configFileOptions{selection(2)})
                    % Overwrite config value
                    obj.cfg.SetValue('Group Data Loading Warnings', configFileOptions{selection(2)});
                    obj.cfg.Save();
                    obj.GroupDataLoadWarnings()
                end
            end
                        
        end
        
        
        % ------------------------------------------------------------
        function val = GetError(obj)
            val = obj.err;            
        end

        
        
        % ------------------------------------------------------------
        function Print(obj, indent)
            obj.logger.Write('%s%s\n', blanks(indent), obj.procStream.output.SetFilename([obj.path, obj.GetOutputFilename()]) );
        end

        
        
        % ----------------------------------------------------------------------------------
        function BackwardCompatability(obj)
            if ~ispathvalid([obj.path, obj.outputDirname])
                mkdir([obj.path, obj.outputDirname])
            end
            src = obj.procStream.output.SetFilename([obj.path, obj.GetOutputFilename('legacy')]);
            dst = obj.procStream.output.SetFilename([obj.path, obj.GetOutputFilename()]);
            if ispathvalid(src)
                if ~pathscompare(src, dst)
                    obj.logger.Write(sprintf('Moving %s to %s\n', src, dst));
                    rootpath = fileparts(dst);
                    try
                        if ~ispathvalid(rootpath)
                            mkdir(rootpath)
                        end
                    	movefile(src, dst);
                    catch
                        obj.logger.Write(sprintf('ERROR: Failed to to move old output to new format\n'));
                    end
                end
            end
        end
        
        
        
        % -------------------------------------------------------
        function Rename(obj, namenew)
            [pnameAcquiredNew, fnameAcquiredNew] = fileparts(namenew);
            [pnameAcquired, fnameAcquired, ext] = fileparts(obj.name);            
            filenameOutput = obj.GetOutputFilename();
            [pnameDerived, fnameDerived] = fileparts(filenameOutput);
            
            pnameAcquired = filesepStandard(pnameAcquired);
            pnameAcquiredNew = filesepStandard(pnameAcquiredNew, 'nameonly:dir');
            pnameDerived = filesepStandard(pnameDerived);
            
            obj.logger.Write(sprintf('Renaming %s to %s', obj.name, namenew));

            if ispathvalid([pnameAcquired, fnameAcquired, ext])
                obj.logger.Write(sprintf('  Moving %s to %s', [pnameAcquired, fnameAcquired, ext], [pnameAcquiredNew, fnameAcquiredNew, ext]));
                %movefile([filenameOutput, ext], [pnameAcquired, namenew, ext]);
            end
            
            
            % Dewrived data
            if ispathvalid([pnameDerived, fnameDerived, '.mat'])
                obj.logger.Write(sprintf('  Moving %s to %s', [pnameDerived, fnameDerived, '.mat'], [pnameAcquiredNew, namenew, '.mat']));
                %movefile([filenameOutput, '.mat'], [pnameDerived, namenew, '.mat']);
            elseif ispathvalid([pnameDerived, fnameDerived, '/', fnameDerived, '.mat'])
                obj.logger.Write(sprintf('  Moving %s to %s', [pnameDerived, fnameDerived, '/', fnameDerived, '.mat'], ...
                    [pnameDerived, fnameDerived, '/', namenew, '.mat']));
                obj.logger.Write(sprintf('  Moving %s to %s', [pnameDerived, fnameDerived], ...
                    [pnameAcquiredNew, namenew]));
                %movefile([filenameOutput, '.mat'], [pnameDerived, namenew, '.mat']);
            end
            
            if ispathvalid([pnameDerived, fnameDerived])
                obj.logger.Write(sprintf('  Moving %s to %s', [pnameDerived, fnameDerived], [pnameDerived, fnameNew]));
                %movefile([filenameOutput, ext], [pnameDerived, namenew, ext]);
            end
%             obj.name = [filesepStandard(pnameNew), fnameNew, ext];
        end
        
        
    end

    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Static class methods implementing runs, subjs, groups processing 
    % flags for quickly calculating required memory and color table
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods (Static)
                
        % ----------------------------------------------------------------------------------
        function out = CondColTbl(arg)
            persistent tbl;
            if nargin==0
                out = tbl;
                return;
            end
            if ~strcmp(arg,'init')
                return
            end
            tbl = distinguishable_colors(128);
        end
   
        
        
        % --------------------------------------------------------------------------------
        function out = SaveMemorySpace(arg)
            persistent v;
            out = [];
                        
            % If first time we call SaveMemorySpace is with a filename argument, that is arg is a char string 
            % rather than a numeric, then we want to set v to true to make sure not to load everything into memory 
            % by default. Later in the Homer3 initalization if we detect our data set is small, we can reverse that 
            % and set the SaveMemorySpace to false to improve responce time. 
            if isempty(v)
                v = true;
            end
            
            if islogical(arg) || isnumeric(arg)
                v = arg;
                out = v;
            elseif ischar(arg)                
                if v
                    out = arg;
                else
                    out = '';
                end
            end
        end
   
                
        % --------------------------------------------------------------------------------
        function out = GroupDataLoadWarnings()
            global cfg
            
            persistent v;
            if ~exist('arg','var')
                v = cfg.GetValue('Group Data Loading Warnings');
            elseif exist('arg','var')
                v = arg;
            end
            out = v;
        end
        
    end
    
end

