function [] = WaveletPCAMot(filename,imInds)
%WaveletPCA.m
%   Detailed explanation goes here
savefilename = filename(1:end-4);
savefilename = strcat(savefilename,'-wvltpcamot.mat');

if exist(savefilename,'file') == 2
    return;
else
    v = VideoReader(filename);
    totalFrames = round(v.Duration*v.FrameRate);
    im = readFrame(v);
    
    if nargin<2
        DIM = size(im);
        imInds = [1,DIM(1),1,DIM(2)];
        im = mean(im(imInds(1):imInds(2),imInds(3):imInds(4)),3);
    else
        im = mean(im(imInds(1):imInds(2),imInds(3):imInds(4)),3);
        DIM = size(im);
    end
    
    % vidTime = 250/1000;
    % numFrames = ceil(vidTime/(1/v.FrameRate));
    % video = zeros(DIM(1),DIM(2),numFrames);
    % WDEC = wavedec3(video,5,'db2');
    % N = size(WDEC.dec,1);
    % all = [];
    % for ii=1:N
    %     all = [all;WDEC.dec{ii}(:)];
    % end
    %
    % fullSize = length(all);
    
    wvltLevel = 1;
    wvltType = 'db6';
    [C,S] = wavedec2(im,wvltLevel,wvltType);
    fullSize = length(C(:));
    
    % online pca
    numPCA = min(1e5,ceil(totalFrames/2));
    times = randperm(totalFrames,numPCA);
    
    q = 500;
    fprintf('Data Size: [%d , %d]\n',fullSize,numPCA);
    data = zeros(fullSize,numPCA);
    
    count = 0;
    while count<numPCA
        v.CurrentTime = (times(count+1)-1)./v.FrameRate;
        im = readFrame(v);
        
        if hasFrame(v)
            count = count+1;
            im2 = readFrame(v);
            im = mean(im(imInds(1):imInds(2),imInds(3):imInds(4)),3);
            im2 = mean(im2(imInds(1):imInds(2),imInds(3):imInds(4)),3);
            [C,~] = wavedec2(im2-im,wvltLevel,wvltType);
            
            data(:,count) = C(:);
        else
            times(count+1) = randperm(totalFrames,1); 
        end
    end
    fprintf('Computing PCA ... \n');
    [W,mu] = PCA(data,q);
    fprintf('PCA Complete ... \n');
    Winv = W';
    % TRANSFORM ALL OF THE DATA INTO IC SPACE
    clear v data;
    v = VideoReader(filename);
    totalFrames = ceil(v.Duration*v.FrameRate);
    
    pcaRep = zeros(totalFrames,q);
    
    meanIm = appcoef2(mu,S,wvltType,0);
    im = readFrame(v);
    im = mean(im(imInds(1):imInds(2),imInds(3):imInds(4)),3);
    [C,~] = wavedec2(im-meanIm,wvltLevel,wvltType);
    pcaRep(1,:) = (Winv*(C(:)-mu))'; % to go the other way W*pcaRep'+mu
    prevIm = im;
    
    checks = round(linspace(2,totalFrames,20));checkcount=1;    
    for ii=2:totalFrames
        if hasFrame(v)
            im = readFrame(v);
            im = mean(im(imInds(1):imInds(2),imInds(3):imInds(4)),3);
            [C,~] = wavedec2(im-prevIm,wvltLevel,wvltType);
            pcaRep(ii,:) = (Winv*(C(:)-mu))';
            prevIm = im;
        end
	if checks(checkcount)==ii
	    fprintf('%3.2f Percent Complete\n',100*ii/totalFrames);
            checkcount = checkcount+1;
	end
    end
    
    if sum(abs(pcaRep(end,:)))<=1e-6
        pcaRep = pcaRep(1:end-1,:);
    end
    
    clear v;
    
    newName = filename(1:end-4);
    newName = strcat(newName,'-wvltpcamot.mat');
    save(newName,'pcaRep','W','Winv','mu','q','wvltLevel','wvltType',...
        'DIM','filename','S','imInds');
    
    disp(['File Completed: ',filename]);
    
end
end

function [Q] = GramSchmidt(A)
[M,N] = size(A);
Q = zeros(M,N);
R = zeros(N,N);

v = zeros(M,1);
for jj=1:N
    v(:) = A(:,jj);
    for ii=1:jj-1
       R(ii,jj) = Q(:,ii)'*v;
       v(:) = v-R(ii,jj)*Q(:,ii);
    end
    R(jj,jj) = norm(v); % v'*v
    Q(:,jj) = v./R(jj,jj);
end

end
