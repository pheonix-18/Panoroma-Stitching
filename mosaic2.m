% Location of the Images
location = './intersection';

% Creating a datastore
ds = imageDatastore(location);

% sequence 1
 indices = [1,2,3,4];
% for imgs folder use only first 2 indices
% for remaining folders can you >=4 images
% sequence 2
 % indices = [1,2,3,4];

% Taking a subset of images from the datastore
subimds = subset(ds, indices);
I = readimage(subimds, 1);

% Converting images to GRAYSCALE for invariant points
Image_Gray = im2gray(I);
% Getting Features using SURF; Can also use Harris Features; SIFT can be
% used from vl_sift library but sift is not giving good results
% Peter's ransacfithomograph.m throwing me errors which I'm unable to fix!
% So I went with SURF
points = detectSURFFeatures(Image_Gray);
[features, points] = extractFeatures(Image_Gray,points);

% Initialize all the transforms to the identity matrix. Note that the
% projective transform is used here because the building images are fairly
% close to the camera. Had the scene been captured from a further distance,
% an affine transform would suffice.
no_of_Images = numel(subimds.Files);
tforms(no_of_Images) = projective2d(eye(3));

% Find size of images
img_size = zeros(no_of_Images,2);

% Iterate over remaining image pairs
for n = 2:no_of_Images
    
    % Store points and features for I(n-1).
    prevPoints = points;
    prevFeatures = features;
        
    % Read I(n).
    I = readimage(subimds, n);
    
    % Converting images to GRAYSCALE for invariant points
    Image_Gray = im2gray(I);    
    
    % Find size of images
    img_size(n,:) = size(Image_Gray);
    
    % Detect and extract SURF features for I(n).
    points = detectSURFFeatures(Image_Gray);    
    [features, points] = extractFeatures(Image_Gray, points);
  
    % Finding correspondence between previous and curr Image Image_Gray
    indexPairs = matchFeatures(features, prevFeatures, 'Unique', true);
       
    matchedPoints = points(indexPairs(:,1), :);
    matchedPointsPrev = prevPoints(indexPairs(:,2), :);        
    
    % Estimate the 3 X 3 Homography between I(n) and I(n-1).
    tforms(n) = estimateGeometricTransform2D(matchedPoints, matchedPointsPrev,...
        'projective', 'Confidence', 95.0, 'MaxNumTrials', 1000);
    
    % Compute H(n) for Image n
    tforms(n).T = tforms(n).T * tforms(n-1).T; 
end

for i = 1:numel(tforms)           
    [xlim(i,:), ylim(i,:)] = outputLimits(tforms(i), [1 img_size(i,2)], [1 img_size(i,1)]);
end

max_img_size = max(img_size);

% Finding the output limits 
xMin = min([1; xlim(:)]);
xMax = max([max_img_size(2); xlim(:)]);

yMin = min([1; ylim(:)]);
yMax = max([max_img_size(1); ylim(:)]);

% Defining the shape of panorama.
width  = round(xMax - xMin);
height = round(yMax - yMin);

% Initialize the panorama using zeros
panorama = zeros([height width 3], 'like', I);

% Alpha Blender
blender = vision.AlphaBlender('Operation', 'Binary mask', ...
    'MaskSource', 'Input port');  

% Create a 2-D spatial reference object defining the size of the panorama.
xLimits = [xMin xMax];
yLimits = [yMin yMax];
panoramaView = imref2d([height width], xLimits, yLimits);

for i = 1:no_of_Images
    
    I = readimage(subimds, i);   
   
    % Transform I into the panorama.
    warpedImage = imwarp(I, tforms(i), 'OutputView', panoramaView);
                  
    % Generate a binary mask.    
    mask = imwarp(true(size(I,1),size(I,2)), tforms(i), 'OutputView', panoramaView);
    
    % Add warpedImage to panoroma
    panorama = step(blender, panorama, warpedImage, mask);
end
figure (1);
montage(subimds.Files);
figure (2);
imshow(panorama)
title("Panoramic View of 2 Sequence Images");