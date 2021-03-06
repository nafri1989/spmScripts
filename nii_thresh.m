function nii_thresh (volNames, normalizeIntensity, maxThresh, maxVal, minThresh, minVal)
%Clip bright and/or dark voxels of input image(s)
% volNames  : name(s) of image(s) to threshold
% normalizeIntensity : if true, brightness scaled from 0..1
% maxThresh : voxels brighter than this value are set to maxVal (if not required, set to inf) 
% maxVal    : output value for voxels that exceed maxThresh in input volume 
% minThresh : voxels darker than this value are set to minVal (if not required, set to -inf) 
% minVal    : output value for voxels that exceed minThresh in input volume 
%Examples
% nii_thresh %prompt user for files and values
% nii_thresh('img.nii',false,inf,inf,0.5, 0); %voxels darker than 0.5 set to 0
% nii_thresh('img.nii',false,0.5-eps,1,0.5, 0); %create binary output
% nii_thresh('img.nii',false,500,500,0, 0); %voxels brighter than 500 set to 500
% nii_thresh(strvcat('i1.nii','i2.nii'),false,1,1,0, 0); %threshold multiple images
% nii_thresh('img.nii',false,-inf,1,inf, 0); %voxels darker than 0.5 set to 0

if ~exist('volNames','var')
 volNames = spm_select(inf,'image','Select images to threshold');
end;
if ~exist('minVal','var')
    answer = inputdlg({'Normalize brightness from 0..1 (0=false, 1=true)', 'Max intensity', 'Set voxels > max intensity to', 'Min intensity', 'Set voxels < min intensity to' }, 'Set thresholds', 1,{'0','Inf','Inf','0.5','0'});
    normalizeIntensity = str2double (cell2mat(answer(1)));
    maxThresh = str2double (cell2mat(answer(2)));   
    maxVal = str2double (cell2mat(answer(3)));
    minThresh = str2double (cell2mat(answer(4)));
    minVal = str2double (cell2mat(answer(5)));
end

doOtsu = (minThresh == inf) || (maxThresh == -inf);
for i=1:size(volNames,1)
    fnm = deblank(volNames(i,:));
    hdr = spm_vol(fnm);
    img = spm_read_vols(hdr);
    if normalizeIntensity
        img = img - min(img(:)); %translate so minimum is zero
        img = img/max(img(:)); %scale so maximum is one
        if (spm_type(hdr.dt,'intt')) %integer input - adjust scaling factor 
            hdr.pinfo = [1/spm_type(hdr.dt,'maxval');0;0];
        end
    end
    if doOtsu
        minThresh = otsuSub(img);
        maxThresh = minThresh;
    end
    imgout = img;
    imgout(img(:) > maxThresh) = maxVal; 
    imgout(img(:) < minThresh) = minVal;    
    fprintf('%s has %d voxels that exceed thresholds %f and %f\n', hdr.fname,round(sum(img(:)> maxThresh)+sum(img(:)< minThresh)), maxThresh,minThresh);
    [pth bnm ext] = spm_fileparts(fnm);
    hdr.fname = fullfile(pth, ['x' bnm ext]);
    spm_write_vol(hdr,imgout);
end;

% --- threshold for converting continuous brightness to binary image using Otsu's method.
function [thresh] = otsuSub(I)
% BSD license: http://www.mathworks.com/matlabcentral/fileexchange/26532-image-segmentation-using-otsu-thresholding
% Damien Garcia 2010/03 http://www.biomecardio.com/matlab/otsu.html
nbins = 256;
if (min(I(:)) == max(I(:)) ), disp('otu error: no intensity variability'); thresh =min(I(:)); return; end; 
intercept = min(I(:)); %we will translate min-val to be zero
slope = (nbins-1)/ (max(I(:))-intercept); %we will scale images to range 0..(nbins-1)
I = round((I - intercept) * slope);
[histo,pixval] = hist(I(:),256); % Probability distribution
P = histo/sum(histo);
%% Zeroth- and first-order cumulative moments
w = cumsum(P);
mu = cumsum((1:nbins).*P);
sigma2B =(mu(end)*w(2:end-1)-mu(2:end-1)).^2./w(2:end-1)./(1-w(2:end-1));
[maxsig,k] = max(sigma2B);
thresh=    pixval(k+1);
if (thresh >= nbins), thresh = nbins-1; end;
thresh = thresh/slope + intercept;
%end otsuSub()