function icc(varargin)
repoDir = fileparts(mfilename('fullpath'));
try
    sub = load(fullfile(repoDir,'data','m2m4_sub_n109.csv'));
catch
    sub = [];
end
p = inputParser;
p.addParameter('fcDir','/scratch/st-tv01-1/hcp/targets');
p.addParameter('rois', {'tpj', 'dlpfc', 'pre_sma'});
p.addParameter('runs', {'REST1', 'REST4', 'MOVIE2','MOVIE4'});
p.addParameter('tr',[],@(x) isnumeric(x) && numel(x)==1);
p.addParameter('sub',sub);
p.addParameter('logfile','');
p.addParameter('JobStorageLocation','',@ischar);
p.addParameter('cores',feature('numcores'));

p.parse(varargin{:});
inputs = p.Results;
fcDir = inputs.fcDir;
sub = inputs.sub;
rois = inputs.rois;
runs = inputs.runs;
cond = unique(cellfun(@(x) x(1:end-1),runs,'UniformOutput',0)); % get conditions
logfile = inputs.logfile;

if ~isempty(logfile)
    fid = fopen(logfile,'w');
else
    fid = 0;
end
tr = inputs.tr;
% start parpool
util.start_parpool('numCores',inputs.cores,'JobStorageLocation',inputs.JobStorageLocation);
% loop over rois
for i=1:numel(rois)
    % loop over condtions
    for j=1:numel(cond)
        % pick runs matching condition
        r = find(startsWith(runs,cond{j}));
        % preallocate arrays
        tmp = loadData(fcDir, sub(1), runs{end},rois{i}, tr);
        dim = size(tmp);
        edges = dim(1)*dim(2);
        run1 = zeros(numel(sub),edges,'single');
        run2 = zeros(numel(sub),edges,'single');
        % loop over and load subject data
        tic
	xprintf(fid,'%s %s\n', rois{i},cond{j});
        parfor s=1:numel(sub)
            tmp1 = loadData(fcDir, sub(s), runs{r(1)}, rois{i}, tr);
            tmp2 = loadData(fcDir, sub(s), runs{r(2)}, rois{i}, tr);
            run1(s,:) = reshape(tmp1,1,edges);
            run2(s,:) = reshape(tmp2,1,edges);
        end
	xprintf(fid,'\n\tsubjects loaded in %.1f minutes',toc/60);
        icc = zeros(edges,1);
        % loop over edges, calculate icc
        tic
	parfor e=1:size(run1,2)
            if ~mod(e, 100000)
                xprintf(0,'\n\t\tedge %d',e);
            end
            icc(e) = util.icc21([run1(:,e) run2(:,e)]);
        end
	xprintf(fid,'\n\t%d edge iccs calculated in %.1f min',edges,toc/60);
        % save data
        if isempty(inputs.tr)
            file = fullfile(fcDir,sprintf('icc_%s_%s_n%d.txt',rois{i},cond{j}, numel(sub)));
        else
            file = fullfile(fcDir,sprintf('icc_%s_%s_%dtr_n%d.txt',rois{i},cond{j}, tr, numel(sub)));
        end
	writematrix(reshape(icc,dim(1:2)),file);
        xprintf(fid,'%s written!',file);
    end
end
if fid
    fclose(fid);
end
end


function mat = loadData(matDir, sub, run, roi, tr)
if isempty(tr)
    mat = load(fullfile(matDir,sprintf('sub%d_%s_%s.csv', sub, run, roi)));
else
    mat = load(fullfile(matDir,sprintf('sub%d_%s_%s_%dtr.csv', sub, run, roi, tr)));
end
end

function xprintf(fid, varargin)
if fid
    fprintf(fid, varargin{:});
else
    fprintf(varargin{:});
end
end
