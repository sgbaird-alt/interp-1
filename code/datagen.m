function [meshList,propList,K,five,usv,Ktr] = ...
	datagen(sampleMethod,octsubdiv,sampleType,varargin)
%--------------------------------------------------------------------------
% Author: Sterling Baird
%
% Date: 2020-07-01
%
% Description:
%
% Inputs:
%		samplingMethod	===	type of data generation scheme to use.
%
%			'random'
%				randomly generates data from a uniform distribution in the
%				non-negative orthant.
%
%			'Kim2011'
%				reads in the iron grain boundary energy simulation data from
%				[1].
%
%			'5DOF'
%				produces a 5DOF mesh with tetrahedra in the misorientation FZ
%				and spherical triangles in the BP FZ.
%
%		sampleType		===	type of sampling scheme
%										'mesh' -- generate mesh only
%
%										'data' -- generate mesh and property values
%
% Outputs:
%		meshList		===	rows of vertices of mesh.
%
%		propList		===	column of property values (or empty array if
%								sampleType == 'mesh')
%
% Dependencies:
%		Kim2011_FeGBEnergy.txt
%		mesh5DOF.m
%		allcomb.m (if using sampleMethod == 'Rohrer2009')
%		addpathdir.m
%
% References
%		[1] H.K. Kim, W.S. Ko, H.J. Lee, S.G. Kim, B.J. Lee, An
%		identification scheme of grain boundaries and construction of a grain
%		boundary energy database, Scr. Mater. 64 (2011) 1152�1155.
%		https://doi.org/10.1016/j.scriptamat.2011.03.020.
%
% Notes:
%		Re-work argument inputs using "arguments" validation syntax
%--------------------------------------------------------------------------

%% setup
usual = 3; %usual # of variables

pseudoQ = contains(sampleMethod,'pseudo');

if pseudoQ
	str_id = strfind(sampleMethod,'_pseudo');
	sampleMethod = sampleMethod(1:str_id-1); %assumes _pseudo is at end, and remove it
end

if nargin > usual
	res = []; %double
	nint = []; %double
	sphK = []; % double
	ocuboOpts = []; % struct
	% initial new variables and add as input to var_names
	S = var_names(res,nint,sphK,ocuboOpts); %package into struct
	vars = fields(S); %get fields (i.e. strings of variable names)
	
	irange = 1:nargin-usual;
	for i = irange
		var = vars{i};
		S.(var) = varargin{i};
	end
	
	load_method = 'eval';
	switch load_method
		case 'eval'
			for i = 1:length(vars)
				var = vars{i};
				temp = S.(var); %#ok<NASGU> %temporary value of vName
				evalc([var '= temp']); %assign temp value to a short name
			end
		case 'manual'
			res = S.(vars{1});
			nint = S.(vars{2});
			sphK = S.(vars{3});
			ocuboOpts = S.(vars{4});
	end
end


%get filenames, if any
switch sampleMethod
	case 'Kim2011'
		filelist = {'Kim2011_FeGBEnergy.txt'};
	case 'Olmsted2004'
		filelist = {'olm_octonion_list.txt','olm_properties.txt'};
end

%add filename directories to path, if any
switch sampleMethod
	case {'Kim2011','Olmsted2004'}
		%add folders to path
		addpathdir(filelist)
end

%% generate data
switch sampleMethod
	case 'random'
		seed = 10;
		rng(seed)
		
		%transpose to preserve rng sequence of pts with different number of datapts
		datatemp = rand(d+1,ndatapts).';
		meshList = zeros(d,ndatapts);
		
		for i = 1:ndatapts
			meshList(i,:) = datatemp(i,1:end-1)/vecnorm(datatemp(i,1:end-1));
		end
		propList = datatemp(:,end);
		
	case 'Kim2011'
		meshTable = readtable(filepath{1},'HeaderLines',9,'ReadVariableNames',true);
		varNames = meshTable.Properties.VariableNames; %Euler angles (misorientation), the polar & azimuth (inclination), GBE (mJ/m^2)
		datatemp = table2array(meshTable);
		
		meshList = datatemp(:,1:end-1);
		propList = datatemp(:,end);
		
	case 'Rohrer2009'
		%for now (2020-07-02) just gets the meshpoints of the grid they used,
		%rather than the triple junction, and then later assigns GB energy
		%based on BRK function
		
		step = 10; %degrees
		phi1_list = 0:step:90;
		cap_phi_list = cos(phi1_list);
		phi2_list = phi1_list;
		theta_list = cap_phi_list;
		phi_list = phi1_list;
		
		meshList = allcomb(phi1_list,cap_phi_list,phi2_list,theta_list,phi_list);
		
		%initialize
		npts = length(meshList);
		five(npts) = struct;
		five(1).q = [];
		five(1).nA = [];
		
		%convert to q,nA representation
		for i = 1:length(meshList)
			phi1 = meshList(i,1);
			cap_phi = meshList(i,2);
			phi2 = meshList(i,3);
			theta = meshList(i,4);
			phi = meshList(i,5);
			
			%the next few lines need to be checked to get them consistent with
			%convention used in Rohrer for angles
			five(i).q = rod2q([phi1,cap_phi,phi2]);
			[x,y,z] = sph2cart(theta,phi);
			five(i).nA = [x,y,z];
		end
		
	case 'Olmsted2004'
		meshList = readmatrix(filepath{1},'NumHeaderLines',1,'Delimiter',' ');
		meshList = meshList(:,1:8); %octonion representation, gets rid of a random NaN column..
		
		propList = readmatrix(filepath{2},'NumHeaderLines',1,'Delimiter',' '); %properties
		propList = propList(:,1); %1st column == GB energy
		
	case '5DOF'
		%resolution in misorientation FZ
		% 		resDegrees = 10;
		%subdivisions of spherical triangles of BPs, n == 1 does nothing, n
		%== 2 does one subdivision, n == 3 does 2 subdivisions etc.
		% 		nint = 1;
		featureType = 'resolution';
		
	case {'5DOF_interior','5DOF_interior_pseudo'}
		featureType = 'interior';
		
	case {'5DOF_exterior','5DOF_exterior_pseudo'}
		featureType = 'exterior';
		
	case '5DOF_vtx'
		featureType = 'vertices';
		
	case '5DOF_vtx_deleteO'
		featureType = 'vtx_deleteO';
		
	case '5DOF_vtx_deleteOz'
		featureType = 'vtx_deleteOz';
		
	case '5DOF_ext_deleteO'
		featureType = 'ext_deleteO';
		
	case '5DOF_misFZfeatures'
		featureType = 'misFZfeatures';
		
	case '5DOF_oct_vtx'
		featureType = 'vtx_deleteOz';
		%the rest gets taken care of later
		
	case {'5DOF_hsphext','5DOF_hsphext_pseudo'}
		featureType = 'vtx_deleteOz';
		
	case {'5DOF_exterior_hsphext','5DOF_exterior_hsphext_pseudo'}
		featureType = 'exterior';
		
	case {'ocubo'}
		featureType = 'ocubo';
		%unpack options
		n = ocuboOpts.n;
		method = ocuboOpts.method;
		sidelength = ocuboOpts.sidelength;
		%get cubochorically sampled octonions
		meshList = get_ocubo(n,method,sidelength);
		five = GBoct2five(meshList);
end

%5DOF cases
if contains(sampleMethod,'5DOF')
	ctrcuspQ = false;
	[five,sept,o] = mesh5DOF(featureType,ctrcuspQ,res,nint);
	meshList = sept;
end

sz = size(meshList); %store size of degenerate meshList
%reduce to unique set of points
[~,IA] = uniquetol(round(meshList,6),1e-3,'ByRows',true);
meshList = meshList(IA,:);
%pare down five to a unique set of points
five = five(IA);

%originally implemented for just '5DOF_oct_vtx' and 'hsphext'
%get symmetrized octonions with respect to two points ('O' and
%'interior', both +z)
if contains(sampleMethod,'5DOF_')
	savename = [sampleMethod(6:end) '_pairmin.mat'];
else
	savename = [sampleMethod '_pairmin.mat'];
end

if size(meshList,2) == 7
	meshList = [meshList zeros(size(meshList,1),1)];
end

if ~pseudoQ
	if contains(sampleMethod,'oct_vtx')
		opts = {'o2addQ',true,'method',2};
	else
		opts = {'o2addQ',false,'method',2};
	end
	[meshList,usv,five,~,~] = get_octpairs(meshList,five,savename,opts{:}); %find a way to not call this for 'data'
	meshList = proj_down(meshList,1e-6,usv);
else
	try
		load(savename,'octvtx','usv')
		% 	meshListTemp = proj_down(meshList,1e-6,usv);
		meshList = proj_down(octvtx,1e-6,usv);
	catch
		warning('error with meshList = proj_down(octvtx,1e-6,usv); or load')
		[meshList,usv] = proj_down(meshList,1e-6);
	end
% 	if isempty(meshListTemp)
% 		warning('creating new usv')
% 		[meshList,usv] = proj_down(meshList,1e-6);
% 	end
end
if ~isempty(meshList)
	projupQ = true;
else
	projupQ = false;
end
%% Subdivide octonions, convex hull
if octsubdiv > 1
	
	if contains(sampleMethod,'hsphext')
		if ~pseudoQ
			[Ktr,K,meshList] = hsphext_subdiv(meshList,octsubdiv,true);
		else
			tricollapseQ = false;
			[Ktr,K,meshList] = hsphext_subdiv(meshList,octsubdiv,tricollapseQ);
		end
	elseif pseudoQ
		tricollapseQ = false;
		[~,K,meshList] = hypersphere_subdiv(meshList,sphK,octsubdiv,tricollapseQ);
		Ktr = [];
	else
		[Ktr,K,meshList] = hypersphere_subdiv(meshList,sphK,octsubdiv,true);
	end
	
% 	if any([strcmp(sampleMethod,'5DOF_oct_vtx'),contains(sampleMethod,'hsphext')])
		%restore null dimensions for oct --> five
		
		if projupQ
			meshList = proj_up(meshList,usv);
			projupQ = false;
		end
% 	end
	
	five = GBoct2five(meshList);
	
elseif (exist('sphK','var') ~= 0)
	%create K if it exists & is empty
	if ~pseudoQ
		if isempty(sphK)
			if contains(sampleMethod,'hsphext')
				[Ktr,K,meshList] = hsphext_subdiv(meshList,1);
			else
				K = sphconvhulln(meshList);
			end
		else
			K = sphK;
		end
	else
		K = [];
	end
		
else
	if ~pseudoQ
		K = sphconvhulln(meshList);
	else
		K = [];
	end
end

if projupQ
	meshList = proj_up(meshList,usv);
end

%package geometry into "five" (e.g. 'A', 'O', 'AC', etc.)
geomQ = true;
if geomQ
	for i = 1:length(five)
		five(i).geometry = findgeometry(disorientation(five(i).q,'cubic'));
	end
end

%normalize octonions
assert(size(meshList,2) == 8,['meshList should have 8 columns, not ' int2str(size(meshList,2))])
meshList = normr(meshList);

disp(' ')
disp(['total of ' int2str(size(meshList,1)) ' after oct subdivision.'])

%% Compute GB Energies

% save('temp.mat')

if strcmp(sampleType,'data')
	if any([contains(sampleMethod,{'5DOF','ocubo'}),strcmp(sampleMethod,'Rohrer2009')])
		
		disp('GB5DOF')
		propList = GB5DOF_setup(five);
		
	else
		propList = [];
		warning('propList is empty. Ok if sampleType == mesh. Otherwise, did you add to switch case, or is "five" empty?')
	end
end

if exist('usv','var') == 0
	usv = [];
end

if exist('Ktr','var') == 0
	Ktr = [];
end

end %datagen

%-----------------------------HELPER FUNCTIONS-----------------------------
function propList = GB5DOF_setup(five)
%Compute 5DOF GB energy from BRK function

% Compute GB matrices
qB_Lab = vertcat(five.q);
nGB = size(qB_Lab,1);
qA_Lab = repmat([1 0 0 0],nGB,1);
nA_Lab = vertcat(five.nA).';

[gA_R,gB_R] = constructGBMatrices(qA_Lab,qB_Lab,nA_Lab,'livermore');

%Calculate GB Energies
f = waitbar(0,['calculating GB energies for ',int2str(nGB),' points.']);
E(nGB) = struct;
E(1).Ni = [];
for k = 1:nGB
	waitbar(k/nGB,f)
	E(k).Ni = GB5DOF(gA_R(:,:,k),gB_R(:,:,k),'Ni');
	%     E.Al(k) = GB5DOF(gA_R(:,:,k),gB_R(:,:,k),'Al');
	%     E.Au(k) = GB5DOF(gA_R(:,:,k),gB_R(:,:,k),'Au');
	%     E.Cu(k) = GB5DOF(gA_R(:,:,k),gB_R(:,:,k),'Cu');
end
close(f);
%E.Ni = reshape(E.Ni,size(x)); %x was an output from sphere() in other code

propList = vertcat(E.Ni);
end



%----------------------------CODE GRAVEYARD--------------------------------
%{




	case '5DOF'
		%resolution in misorientation FZ
% 		resDegrees = 10;
		%subdivisions of spherical triangles of BPs, n == 1 does nothing, n
		%== 2 does one subdivision, n == 3 does 2 subdivisions etc.
% 		nint = 1;
		featureType = 'resolution';
		
	case '5DOF_interior'
% 		resDegrees = 10;
% 		nint = 3;
		featureType = 'interior';
		
	case '5DOF_exterior'
% 		resDegrees = 10;
% 		nint = 2;
		featureType = 'exterior';
		
	case '5DOF_vtx'
% 		resDegrees = 5;
% 		nint = 1;
		featureType = 'vertices';
		
	case '5DOF_vtx_deleteO'
% 		resDegrees = 5;
% 		nint = 1;
		featureType = 'vtx_deleteO';
		
	case '5DOF_ext_deleteO'
% 		resDegrees = 5;
% 		nint = 1;
		featureType = 'ext_deleteO';
		
	case '5DOF_misFZfeatures'
% 		resDegrees = 5;
% 		nint = 1;
		featureType = 'misFZfeatures';


	if isempty(sphK)
		[Ktr,K,meshList] = hypersphere_subdiv(meshList,[],octsubdiv);
	else
		[Ktr,K,meshList] = hypersphere_subdiv(meshList,sphK,octsubdiv);
	end


sz = size(meshList); %store size of degenerate meshList
%reduce to unique set of points
[meshList,IA] = uniquetol(meshList,1e-6,'ByRows',true);

%pare down five to a unique set of points
[row,~] = ind2sub(sz,IA);
% row = sort(row);
five = five(row);


[row,~] = ind2sub(sz,IA);


	%create K if it exists & is empty
	if ~isempty(sphK)
		K = sphconvhulln(meshList);
		% 		K = convhulln(meshList);
	end

if strcmp(sampleMethod,'oct_vtx')
	%project back into d-dimensional space
	meshList = padarray(meshList,[0 ndegdim],'post')*v'+mean(pts);
end

% 	load('octvtx_pairmin.mat','five','pts','sphK','usv','avg')
% 	meshList = pts;
	%remove null dimensions
	% 		[pts,V,avg] = proj_down(pts);
	% 		sphK = sphconvhulln(pts);

% if strcmp(sampleMethod,{'5DOF_oct_vtx','5DOF_hsphext')
% 	meshList = pts; %just make sure to output V
% end


		meshList2 = meshList;


switch sampleMethod
	case {'5DOF','5DOF_interior','5DOF_exterior','5DOF_vtx','5DOF_vtx_deleteO',...
			'5DOF_vtx_deleteOz','5DOF_ext_deleteO','5DOF_misFZfeatures',...
			'5DOF_oct_vtx','5DOF_hsphext','5DOF_exterior_hsphext'}
		ctrcuspQ = false;
		[five,sept,o] = mesh5DOF(featureType,ctrcuspQ,res,nint);
		meshList = sept;
end


	switch sampleMethod
		case {'5DOF','5DOF_interior','5DOF_exterior','5DOF_vtx',...
				'5DOF_misFZfeatures','Rohrer2009','5DOF_vtx_deleteO',...
				'5DOF_vtx_deleteOz','5DOF_oct_vtx','5DOF_hsphext',...
				'5DOF_exterior_hsphext'}
			disp('GB5DOF')
			propList = GB5DOF_setup(five);
			
			
		otherwise
			propList = [];
			warning('propList is empty. Ok if sampleType == mesh. Otherwise, did you add to switch case, or is "five" empty?')
	end

% if any([strcmp(sampleMethod,'5DOF_oct_vtx'),contains(sampleMethod,'hsphext')])
%get symmetrized octonions with respect to two points ('O' and
%'interior', both +z)
savename = [sampleMethod(6:end) '_pairmin.mat'];
if size(meshList,2) == 7
	meshList = [meshList zeros(size(meshList,1),1)];
end
o2addQ = true;
[meshList,usv,five,~,~] = get_octpairs(meshList,five,savename,o2addQ);
meshList = proj_down(meshList,1e-6,usv);
% end

% 	if any([strcmp(sampleMethod,'5DOF_oct_vtx'),contains(sampleMethod,'hsphext')])
		%restore null dimensions for oct --> five
		meshList = proj_up(meshList,usv);
% 	end

%}
