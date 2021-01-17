function MaskedIm = applyMasktoIm(Im,Mask,fillval)
% jonathan saragosti 
% 02/18/15
% apply a binary mask to an image,

% if ismatrix(Im) && ~ismatrix(Mask)
%     Mask = Mask(:,:,1);
% end

imclass = class(Im);
Mask = eval([imclass,'(Mask)']);

if isequal(size(Im),size(Mask))
    MaskedIm = Im.*Mask;
else
    if ismatrix(Im) && ~ismatrix(Mask)
        Mask = Mask(:,:,1);
    end
    MaskedIm = bsxfun(@times,Im,Mask);
end

%MaskedIm = eval([imclass,'(MaskedIm)']);

% 
% Imsize = size(Im);
% Masksize = size(Mask);
% if ~isequal(Imsize(1:2),Masksize(1:2))
%     error('the first two dimensions of the image and the mask should be equal')
% end
% if size(Imsize,2) == 2
%     dimMask = double(Mask);
% else
%     dimMask = double(repmat(Mask,[1 1 Imsize(3)]));
% end
% MaskedIm = im2double(Im).*dimMask;