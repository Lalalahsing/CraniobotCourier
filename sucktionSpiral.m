function sucktionSpiral(suckDia,circDia,X,Y,thickness,depth,feedrate)
    % Objective: After probing the skull, the user can generate a Gcode program for
    % milling the probed points.
    %
    % Variables:
    % X,Y,Z         Column vectors of probed x,y, and z coordinates of skull in
    %                   work coordinates
    % feedrate      Feedrate of mill (units/min)
    % thickenss     thickness of material
    % depth         depth per pass of mill
    % Choose resolution of points.
    
    centerPos = [X,Y,0];  

    numberPoints = 36;
    resolutionCirc = 2*pi/numberPoints;
    numberCircle = (circDia-(suckDia))*2/suckDia;
    numberPointsTotal = numberPoints*numberCircle;
    resolutionLen = (circDia-(suckDia))/numberPointsTotal;
    theta = 0:resolutionCirc:2*pi*numberCircle-resolutionCirc;
    length = 0:resolutionLen:(circDia-(suckDia))-resolutionLen;

    % Create circle projection
    Xspiral = centerPos(1) + length.*sin(theta)/2;
    Yspiral = centerPos(2) + length.*cos(theta)/2;
    %offsetVal = 3.0;
    %Zmin = -90; %used to define where the probe should home towards

    thetacircle = 2*pi*numberCircle:resolutionCirc:2*pi*(numberCircle+1)-resolutionCirc;
    Xcircle = centerPos(1) + (circDia-(suckDia))*sin(thetacircle)/2;
    Ycircle = centerPos(2) + (circDia-(suckDia))*cos(thetacircle)/2;
    
    X = [Xspiral,Xcircle];
    Y = [Yspiral,Ycircle];
    nProbedPoints = numel(X);
    nPasses = ceil(thickness/depth);
    
    figure('Name','Surface Map');
    scatter(X,Y);
    axis equal
    xlabel('X-axis Location (mm)');
    ylabel('Y-axis Location (mm)');
    title(sprintf('%d Total Points',nProbedPoints));
    
    % create .txt file to store path
    fileID = fopen('suctionPath.txt','w');

    % make header commands
    fprintf(fileID,'%s\n',strcat("N1 G91; ",...
        "(set to relative coordinates motion)"));
    fprintf(fileID,'%s\n', "N2 G21; (set to millimeters)");
    fprintf(fileID,'%s\n', "N3 G0 Z3; (retract before moving)");
    fprintf(fileID,'%s\n', strcat("N4 G90 G0 X",num2str(centerPos(1)),...
      " Y",num2str(centerPos(2))));
    ln = 4; %line number
    for j = 1:nPasses
        % Loop through each probed point
        ln = ln+1;
        fprintf(fileID,'%s\n', strcat("N", num2str(ln),...
              " G90 G0 X",num2str(X(1)),...
              " Y",num2str(Y(1)),...
              " F",num2str(feedrate)));
        ln = ln+1;
        fprintf(fileID,'%s\n', strcat("N", num2str(ln),...
              " G90 G1 Z",num2str(-min(j*depth,thickness)),...
              " F",num2str(feedrate)));
        ln = ln+1;
        fprintf(fileID,'%s\n', strcat("N", num2str(ln),...
              " G91 G0 Z",num2str(depth-min(j*depth,thickness))));
        if nProbedPoints >= 2
            for i = 2:nProbedPoints
                ln = ln+1;
                % Move to next X,Y,Z position
                fprintf(fileID,'%s\n', strcat("N", num2str(ln),...
                  " G90 G1 X",num2str(X(i)),...
                  " Y",num2str(Y(i)),...
                  " Z",num2str(-min(j*depth,thickness)),...
                  " F",num2str(feedrate)));
                ln = ln+1;
                fprintf(fileID,'%s\n', strcat("N", num2str(ln),...
                  " G91 G0 Z",num2str(depth-min(j*depth,thickness))));
            end
        end
        % Go back to the starting point of the circle so we can
        % vertically mill down the next loop of ii
        ln = ln+1;
        fprintf(fileID,'%s\n', strcat("N", num2str(ln)," G91 G0 Z3"));
        %ln = ln+1;
        %fprintf(fileID,'%s\n', strcat("N", num2str(ln),...
        %  " G1 Z",num2str(Z(1)-min(j*depth,thickness))));
    end

    % make footer commands
    ln = ln+1;
    fprintf(fileID,'%s\n',strcat("N", num2str(ln)," M2; (Program Complete)"));
    fclose(fileID);
end
